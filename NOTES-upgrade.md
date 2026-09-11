# Upgrading cmbpayroll

Consolidates `upgrade-notes-may-2026.txt` and `upgrade-notes-july-2026.txt`,
which were untracked scratch files. Rewritten 2026-09-10 to drop the guesses
that turned out wrong, keep the findings that are still load-bearing, and put
the forward plan first.

Companion document: `NOTES-remove-dossier.md` (see [Dossier](#dossier) below).

---

## Where we are

| | develop / master | upgrade_app |
| --- | --- | --- |
| Ruby | 2.7.4 | 3.2.10 |
| Rails | 5.1.6.2 | 6.1.7.10 |
| `config.load_defaults` | 5.1 | 6.1 |
| Autoloader | classic | zeitwerk |
| Test suite | 596 tests, green | 588 tests, green |
| Deployed to production | yes | no |

`upgrade_app` is current with `develop` as of 2026-09-10 and the full suite is
green on both. The remaining deprecation noise is `PG::Coder.new(hash)` from
`pg 1.6.3` against `activerecord 6.1` — gem version skew, not app code, and it
clears itself at Rails 7.1.

Everything the May and July notes listed as blocking is done. What's left is
sequencing, not debugging.

---

## The plan

### 1. CI — done

Landed as `.github/workflows/ci.yml`. This was item 9 on the old list and it
should have been item 1. Every systemic problem the upgrade cost us was
CI-shaped:

- the Yoda fixture (`role: supervisor`, never a valid enum value) took out all
  574 tests at once
- `config/environments/production.rb` had a duplicate trailing `end` — a syntax
  error that only loads under `RAILS_ENV=production`, so nothing in test or dev
  would ever have caught it, and it would have surfaced as a failed deploy
- the `params:` double-wrap broke ~10 controller test files identically
- capybara was never in the Gemfile, so 8 browser tests silently hadn't run in
  years

Four more Rails minors without CI reproduces all of that. The gating job runs
three things, because `bin/rails test` alone misses the last two — it runs with
`eager_load = false` and never loads `production.rb`, which is exactly how the
duplicate `end` survived:

    bin/rails test              # 588 tests
    bin/rails zeitwerk:check    # eager loads everything, incl. lib/
    RAILS_ENV=production bin/rails runner '...'   # actually loads production config

`ruby -c` is what caught the duplicate `end`, but it only catches syntax, not a
runtime config error. Booting the production environment catches both. It needs
`SECRET_KEY_BASE` (test self-generates one; production does not) and a
`DATABASE_URL`, because the production section of `database.yml` carries no
credentials — they live on the server as a Capistrano linked file.

`bin/rails test:system` runs in a separate **non-gating** job; see
[Flakiness](#flakiness) for why, and what would let it become gating.

#### The `db/wages.sql` problem

`db/wages.sql` is deliberately never committed, but `db/seeds.rb` reads it and
`test/test_helper.rb` loads seeds at require time — so on a fresh clone, which
is exactly what CI is, **every test fails before the first assertion**. CI
rebuilds it from an encrypted repo secret:

    gzip -9 -c db/wages.sql | base64 -w0 | gh secret set WAGES_SQL_GZ_B64

~2 KB encoded, against a 48 KB limit; the round trip is byte-identical. Two
things to keep in mind:

- **This repo is public, so its build logs are public.** A failing test prints
  real wage figures (`Expected: 42010`). The secret keeps the *table* out of
  the repo; it does not keep figures out of a red build's log. Separately, 22
  of the 120 distinct basewage figures are already in tracked files — e.g.
  `wage_test.rb:92` asserts `42010`, and one test is *named*
  `test_Test_Payslip_72474`.
- **Fork PRs receive no secrets**, so that step fails there by design.

Alternatives, if the above isn't an acceptable trade: a self-hosted runner
(`cp` the file in; but GitHub advises against self-hosted runners on public
repos, since a fork PR can run code on the machine); a committed synthetic
wages file (measured: 558 of 588 tests still pass — the 30 that fail are the
money-verification ones in `payslip_test`, `vacation_test`, `employee_test`,
`wage_test`, `tax_test`); or making the repo private, after which the file can
simply be tracked.

### 2. Prepare the server, then ship 6.1

**This is the item with no owner and no date, and it's the one that gates
everything else.**

`config/deploy.rb` has no rbenv/rvm integration and no Ruby pin — production
runs whatever Ruby Passenger was built against, currently 2.7.4. So shipping
6.1 means:

1. Install Ruby 3.2.10 on `tom`
2. Rebuild Passenger against it, point `PassengerRuby` at the new binary
3. Deploy (`set :branch, 'master'`, so this follows a merge to master)

The nuance that makes this a coordinated cutover rather than prep work:
**rebuilding Passenger for 3.2 breaks the currently-deployed 2.7 app.** There's
no "get the server ready in advance" version of step 2 unless you go through an
rbenv shim you can flip back. Budget a window, and have the previous release
directory ready to roll back to.

Also in play during that window: two bundler generations. Bundler 4.x breaks
Ruby 2.7.4, so 2.1.4 has to stay installed for the old lockfile to resolve, and
Capistrano reads `BUNDLED WITH` from whichever lockfile is deployed.

**Ship before continuing to 7.0.** We just paid the `develop` → `upgrade_app`
catch-up merge once. That cost recurs every week the branch sits. Merging
collapses divergence to zero and turns the next hop into an ordinary feature
branch off `develop` rather than a long-lived parallel universe.

### 3. 6.1 → 7.0 → 7.1 → 7.2 → 8.x

One minor per branch, each merged and deployed before the next starts. Current
latest is 8.1.3.1.

Known content, by hop:

- **7.0** — `errors[]` returns a copy, so `errors[:base] << msg` silently
  becomes a no-op (already fixed on develop in 846ce47). Turbolinks is replaced
  by Turbo as the default, though turbolinks 5.2.1 keeps working. Zeitwerk
  becomes mandatory — already done.
- **7.1** — clears the `PG::Coder` deprecation. `config/secrets.yml` deprecated.
- **7.2** — **`config/secrets.yml` is removed.** This is a hard blocker for this
  hop and needs real work: `secrets.yml` is a Capistrano linked file
  (`config/deploy.rb:8`), so the migration to credentials or ENV has a
  deployment half as well as a code half. Free until then; not optional at then.
- **8.x** — no known blocker in this app yet.

---

## Two things that are *not* work

Both source files worried about these. Neither is real:

**Webpacker.** The May notes flagged a possible "double migration" — Rails 6
defaults to Webpacker, Rails 8 moves to importmaps, so adopting one to abandon
it later. This app has no Webpacker at all: no `package.json`, no
`config/webpack*`, just sprockets 4.2.2 / sprockets-rails 3.5.2. There is
nothing to migrate and nothing to avoid.

**Sprockets.** Propshaft is the default for *new* Rails 7+/8 apps. It is not a
forced migration; sprockets-rails carries forward. Not on the critical path.

**And one more:** Ruby 3.2.10 satisfies every Rails version we're targeting.
Verified against the published gemspecs — Rails 7.0 and 7.1 require `>= 2.7.0`,
7.2 requires `>= 3.1.0`, and 8.0/8.1 require `>= 3.2.0`. **There is no second
Ruby migration between here and Rails 8.1.** The May notes' framing of the
destination as "a Rails 8, Ruby 3.4 world" overstated it; 3.4 is optional, not
required.

---

## Principles for the remaining hops

These are the July notes' hardest-won lessons, stated as rules rather than
anecdotes:

1. **One Rails minor per branch.** The original 5.2 → 6.1 jump happened in a
   single commit *that also moved Ruby 2.7.4 → 3.2.10*, skipping Rails 6.0 and
   Ruby 3.0/3.1 entirely. That's why regressions couldn't be attributed to a
   cause — every failure had two candidate explanations.
2. **Ruby bumps get their own commit**, separate from Rails bumps, for the same
   reason. (Moot through 8.1 per above, but the rule stands if 3.4 ever
   happens.)
3. **Bump `config.load_defaults` last.** Enable each `new_framework_defaults_*`
   setting individually, verify, and only then bump the version — otherwise
   `load_defaults` turns them all on at once and you're back to unattributable
   failures. Read the settings out of the installed railties gemspec's
   `load_defaults` case statement, not the shipped template comments; the
   templates are stale and there won't be a template at all for a version you
   skipped.
4. **Cookie/CSRF/session wire-format settings can't be verified by a green test
   suite.** They only manifest across a real deploy against real existing
   sessions. On this branch they were safe to enable wholesale because nothing
   is deployed from it yet. Once 6.1 is in production that stops being true, and
   those settings need a deploy-and-watch of their own.

---

## Landmines — do not undo these

Each of these looks like something to clean up and is not.

**`test/test_helper.rb` loads the seeds twice, deliberately:**

    load Rails.root.join('db', 'seeds.rb')   # primary db, for non-forked runs

    parallelize_setup do |worker|
      load Rails.root.join('db', 'seeds.rb') # each worker's own db
    end

`parallelize(workers: :number_of_processors)` gives each worker its own
schema-loaded database, but `parallelize_setup` only fires when Rails actually
forks — which it doesn't for `PARALLEL_WORKERS=1` or single-file runs. Deleting
the top-level `load` silently breaks those paths: the wages/taxes tables exist
but are empty, and you get wrong payslip numbers rather than an error. This was
found the hard way.

**`rescue Exception => e` in `Payslip.process_payslip`** (`app/models/payslip.rb`)
with a commented-out `# raise e` right beside it. It swallows everything and
returns a half-computed payslip, which is why most 6.1 failures showed up as
`Actual: 0` / `Actual: -1` instead of a stack trace. **Uncomment `raise e` when
triaging the 7.0 hop** — it's the single highest-value debugging move available,
and it will hide root causes again otherwise.

**The `params:` double-wrap.** `test_helper.rb`'s permission helpers
(`assert_admin_permission` and friends) now declare `params:` as a real keyword.
They previously took it positionally while every call site passed it as a
keyword, so Ruby folded it into `{params: {...}}` — double-wrapped. Rails 5.1's
integration helpers had a legacy path that detected a positional hash containing
`:params` and unwrapped it automatically; **6.1 removed that path**, which is
what made a years-old latent bug suddenly break ~10 controller test files. Don't
"simplify" those signatures back.

**Acronym casing.** `CMBReport` → `CmbReport` and `Dossier::XXCustomResponder` →
`XxCustomResponder` were required by zeitwerk: classic autoloading's
`underscore()` direction happens to round-trip these, zeitwerk's
`camelize(filename)` direction does not. Any new class named with an acronym
needs the same treatment. `bin/rails zeitwerk:check` verifies this, and `lib/`
is in `eager_load_paths` specifically so it gets checked too.

<a name="flakiness"></a>
**`bin/rails test:system` flakiness is missing synchronisation, not the dev
box.** An earlier version of this document blamed the swapping dev box and said
"don't chase this as an app bug." That was wrong, and it cost a re-diagnosis.
It reproduces on an idle machine, from a clean clone, serially, with a warm
cache: **0 of 10 runs passed** before the fix.

The mechanism, established by logging every request through
`RedirectToReferrer`:

- Capybara's `click_button` returns when the click is *dispatched*, not when
  the resulting request completes, so the next statement runs mid-navigation.
  Requests were observed arriving out of order — a `visit` landing **before**
  the login POST it was supposed to follow.
- That matters because `store_redirect` runs on *every* request and
  `manage_stored_redirect` drops `session[:referred_by]` as soon as one reaches
  a different controller/action. A single stray out-of-order request silently
  sends the assertion to the wrong page.
- Separately, `vacations.coffee` fires a `days_summary` AJAX call on
  `turbolinks:load` that clears `#days-summary` to `<br>` and then rewrites it.
  Clicking Save inside that window drops the submit entirely — the server
  never receives `POST /vacations` at all.

Measured, 8 tests, `PARALLEL_WORKERS=1`, warm cache:

| configuration | runs passing |
|---|---|
| baseline | 0/10 |
| `wait_for_vacation_form` only | 0/10 |
| + login wait matching `text: 'Log out'` | 6/10, 0 errors |
| + login wait matching `logout_path` href | 18/22, 0 errors |
| + same wait added inside `LoginTest#login_form` | **1/10 — worse** |

Matching the href rather than the text matters because `set_locale` renders
that link in `current_user.language`, and `RedirectTest` submits a form that
*changes* a user's language. Do not "tidy" it back to a text match.

**Do not add the wait to `LoginTest`'s own `login_form` helper.** It was tried
and measured at 1/10. That is a finding, not an oversight.

Falsified along the way, each tested directly — don't redo these: turbolinks
5.2 form interception; `parallelize` (fails serially too); the sprockets asset
cache (cold-vs-warm looked decisive until `assets:precompile` falsified it);
and test-order dependence (the *same* `--seed` run twice diverges).

Residual ~25% is the same dropped `POST /vacations`. CI runs these non-gating
until it's closed out. Note this is structurally invisible on `develop`, where
those three files live in `test/integration/` and use Capybara's in-process
`rack_test` driver with no real browser.

---

## Open items

| Item | Forced by | Notes |
| --- | --- | --- |
| CI workflow | nothing — but everything depends on it | no `.github/workflows`, no `.circleci` |
| Server Ruby 3.2.10 + Passenger rebuild | shipping 6.1 at all | needs an owner and a window |
| `config/secrets.yml` → credentials or ENV | **Rails 7.2** | also a Capistrano linked file |
| `app/models/user.rb:10-27` | nothing | 18 lines of debug notes pasted verbatim into the model, matching the May notes almost word for word. The diagnosis it records was wrong. Delete. |
| `rails-version-change` branch | nothing | 2024, Rails 5.2.8.1 / Ruby 2.6.10 — superseded by this branch, delete to avoid confusion about which path is current |
| `pg 1.6.3` PG::Coder noise | nothing | clears at 7.1, no action |

<a name="dossier"></a>
### Dossier

`upgrade_app` moved dossier to a pinned SHA on the `cetuslabs/dossier` fork
because the last rubygems release (2.13.1) depends on `arel`, which Rails 6.0
absorbed and which has been unmaintained since 2017. The fork is the only way to
keep the gem, so the real question is whether to keep it — and the answer worked
out to no: almost nothing dossier provides is actually used here (gem routes are
explicitly disabled, `Dossier::ReportsController` is unused, the responder is
dead code, and the PDF rendering is thinreports, not dossier).

The full investigation and removal plan is in **`NOTES-remove-dossier.md`**,
which currently lives only on the `remove-dossier-plan` branch. It should be
cherry-picked onto `upgrade_app` (commit `09cdac2`) so it travels with the code
rather than sitting on a branch that's a cleanup candidate.

Not forced by any Rails version. Worth doing before 7.x rather than after, since
every hop re-tests a fork nobody maintains.

### Debt with no deadline

Unmaintained or superseded, but nothing in the roadmap forces them. Listed so
nobody mistakes them for blockers: turbolinks 5.2.1 (→ Turbo), coffee-rails and
the 12 `.coffee` files, jquery-rails 4.3.5, bootstrap-sass 3.4.1.
