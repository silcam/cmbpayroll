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

### 1. CI — do this first

This was item 9 on the old list and it should be item 1 now. Every systemic
problem the upgrade cost us was CI-shaped:

- the Yoda fixture (`role: supervisor`, never a valid enum value) took out all
  574 tests at once
- `config/environments/production.rb` had a duplicate trailing `end` — a syntax
  error that only loads under `RAILS_ENV=production`, so nothing in test or dev
  would ever have caught it, and it would have surfaced as a failed deploy
- the `params:` double-wrap broke ~10 controller test files identically
- capybara was never in the Gemfile, so 8 browser tests silently hadn't run in
  years

Four more Rails minors without CI reproduces all of that. It needs three
commands, not one:

    bin/rails test              # 588 tests
    bin/rails test:system       # the 8 that `bin/rails test` excludes by convention
    RAILS_ENV=production bin/rails runner 'puts Rails.env'   # actually loads production config

The third matters: `ruby -c` is what caught the duplicate `end`, but it only
catches syntax, not a runtime config error. Booting the production environment
catches both.

Secondary benefit: a machine that isn't swapping tells us whether the
`test:system` flakiness really is this dev box (see [Flakiness](#flakiness)).

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
**`bin/rails test:system` flakiness is the dev box, not the app.** A different
subset of tests fails each run, always the same shape: a `click_on` lands on the
pre-click page. Ruled out individually, each tested directly with the flakiness
persisting: turbolinks 5.2's form interception, `parallelize`, and Capybara's
default wait (raising it to 10s made runs 3-4x slower and still flaky, proving
the wait was active and insufficient). Actual cause: this machine swaps heavily
during runs — ~10GB already in swap out of 15GB, free memory bottoming out
around 190MB with active si/so traffic. Headless Chrome + Puma + Postgres + a
desktop browser produce genuine multi-second stalls. **Don't chase this as an
app bug.** It's structurally impossible on `develop` only because those three
files live in `test/integration/` there, using Capybara's in-process `rack_test`
driver with no real browser. CI on a non-swapping machine settles it.

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
