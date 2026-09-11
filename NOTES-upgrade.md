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
**`bin/rails test:system` flakiness was mostly parallelisation.** This section
has now been wrong twice, so read the history before re-diagnosing it a third
time.

- The original note blamed the swapping dev box and said "don't chase this as
  an app bug."
- I replaced that with "it is missing synchronisation, not the dev box," having
  reproduced 0/10 on an idle machine.
- Both were partly right. Machine load genuinely matters — but the dominant
  multiplier was `parallelize`, which was quietly running the system suite four
  times over and starving it.

`parallelize(workers: :number_of_processors)` is declared on
`ActiveSupport::TestCase` in `test_helper.rb`, and
`ActionDispatch::SystemTestCase` inherits from it. Eight system tests were
therefore forking four workers, each booting **its own Puma and its own
headless Chrome**. Rails 6.1 has no `test_parallelization_threshold` — that
arrived in 7.0 — so the tiny suite size does not save you. Logins were timing
out after ~20s waiting for a page to render.

| configuration | runs fully green |
|---|---|
| parallel, 4 workers | 0/5 — 2 to 4 failures *every* run |
| serial | 3/5 |
| serial + the synchronisation waits below | 8/12 |
| all of the above, final suite of 13 tests | **6/6, on a box at load average 8** |

The fix is in `test/application_system_test_case.rb` and needs **two**
overrides, not one. `test_order` alone is not enough: minitest partitions
suites on `test_order`, but `Runnable.run` dispatches each test through
`run_one_method`, and `parallelize_me!` overrides *that* to push onto the
executor — so the suite lands in the serial partition and then hands every test
to the workers anyway. Measured: with only `test_order` changed, a 3-test file
still booted 3 Pumas. Unit tests still parallelise; only system tests are
serial.

This mattered for CI too, and would have been invisible: `ubuntu-latest`
runners are 2–4 cores, so the non-gating system job would have been permanently
red and permanently ignored.

Two real synchronisation gaps remain, and both are app behaviour rather than
test sloppiness:

- `store_redirect` runs on *every* request and `manage_stored_redirect` drops
  `session[:referred_by]` as soon as one reaches a different
  controller/action — so a single stray request sends an assertion to the wrong
  page. See "RedirectToReferrer needs rewriting" below; this is a real
  user-facing fragility, not only a test artifact.
- `vacations.coffee` fires a `days_summary` AJAX call on `turbolinks:load` that
  clears `#days-summary` to `<br>` and then rewrites it. Clicking Save inside
  that window drops the submit entirely — the server never receives
  `POST /vacations` at all. `wait_for_vacation_form` covers it.

`wait_for_login` matches the logout link's **href**, not its text, because
`set_locale` renders that link in `current_user.language` and `RedirectTest`
submits a form that *changes* a user's language. Text matching measured 6/10
against 18/22 for the href. Do not "tidy" it back to a text match.

**Do not add the wait to `LoginTest`'s own `login_form` helper.** Measured
1/10. That is a finding, not an oversight.

Falsified, each tested directly — don't redo these: turbolinks 5.2 form
interception; the sprockets asset cache (cold-vs-warm looked decisive until
`assets:precompile` falsified it); test-order dependence (the same `--seed`
twice diverges); waiting for `jQuery.active` to reach 0 before clicking (2/10);
and Chrome's `--disable-renderer-backgrounding` /
`--disable-background-timer-throttling` / `--disable-backgrounding-occluded-windows`
flags (no improvement — reverted rather than left in as cargo cult).

Note `parallelize` appears in an earlier draft's falsified list. That was
measured before the fix above and is simply wrong; it is the single biggest
factor.

What is left is an intermittent **dropped interaction**: a click or a keystroke
that Selenium reports as delivered and the browser never acts on. Confirmed
directly by reading a field's value back through JS immediately after
`fill_in` — `"Skywalker"` where `"Starkiller"` had just been typed, with no
turbolinks preview in flight. It is strongly load-sensitive, which is why the
very first version of this note was not simply wrong about the dev box.
`fill_field` (in `ApplicationSystemTestCase`) exists so that when this happens
the test fails *at the fill*, instead of ten seconds later at an unrelated
assertion pointing to the wrong line.

**What would let the system job become gating:** the dropped interaction above
being closed out, evidenced by the full suite running green across ~20
consecutive runs on a loaded box rather than an idle one. Parallelisation is no
longer the blocker; this is. Note the whole problem is structurally invisible
on `develop`, where the original three files live in
`test/integration/` and use Capybara's in-process `rack_test` driver with no
real browser.

<a name="form-with"></a>
**`form_with` silently stopped being remote — found in `/admin/estimatepay`.**
The first real 6.1 regression caught by a user rather than by the suite, and a
good illustration of the shape to watch for.

`app/views/admin/estimate_pay.html.erb` had:

```erb
<%= form_with url: "...json", id: 'estimate-form', remote: true do |f| %>
```

`form_with` takes `local:`, **not** `remote:` — `remote:` belongs to `form_for`
and `form_tag`, and `form_with` silently drops the unrecognised option rather
than raising. That was harmless for years because `form_with` was remote by
default. `load_defaults 6.1` sets
`config.action_view.form_with_generates_remote_forms = false`, so the form
started rendering with **no `data-remote` at all**: UJS ignored it, the browser
did a plain POST to the `.json` URL, and the user was shown raw JSON.

Fixed by using `local: false`. Verified by rendering the template both ways.

A second, older bug sat behind it: `admin.coffee` bound its `ajax:success`
handler with `$(document).ready`, which does not fire when Turbolinks swaps the
body — and `/admin/estimatepay` is reached by a `link_to` from the admin index,
which Turbolinks intercepts. So even with the XHR working, nothing wrote the
answer into the page unless you loaded the URL directly. Every other file in
`app/assets/javascripts/` already used `turbolinks:load`; this one was the odd
one out. That explains why the page was broken *differently* in production,
which is still on the pre-upgrade Rails.

**The generalisable lesson:** options that Rails silently ignores are invisible
until a default flips. `grep -rn "form_with" app/views/` before each remaining
hop — there are only two uses today (`departments/_form` correctly passes
`local: true`), so this is cheap insurance.

The regression guard lives in `test/controllers/admin_controller_test.rb`
(`assert_select "form#estimate-form[data-remote=?]"`), not only in the system
test, because it is a property of rendered markup and can therefore be checked
deterministically. Confirmed it fails without the fix. The system test covers
what markup cannot: that the handler is bound when the page is reached through
a Turbolinks link.

<a name="redirect-rewrite"></a>
**RedirectToReferrer needs rewriting — come back to this.** Not done on this
branch on purpose: it is app behaviour change, and the 6.1 diff should stay a
pure upgrade.

`store_redirect` is already a `before_action` on `ApplicationController`, so
every controller has it — nothing is missing a callback. The problem is the
expiry rule. `manage_stored_redirect` keeps a stored redirect alive for exactly
one controller/action pair:

```ruby
delete_redirect if session[:referred_to] != [controller_name, action_name]
```

The happy path works — `GET /users/5/edit?referred_by=/vacations` stores it,
`PATCH /users/5` stamps and does not delete, `follow_redirect` fires. But *any*
intervening controller request between loading the form and submitting it
consumes the one hop, and the redirect is gone before `update` ever calls
`follow_redirect`. That is reachable by a real user: open the edit form from
the Welcome link, glance at another page or hit back, then submit — you land on
`users_path` instead of where you came from.

The codebase already contains the robust pattern. `VacationsController` does
not depend on the session at all: `_vacation_form.html.erb` carries
`hidden_field_tag "referred_by"`, and `redirect_user` reads
`params[:referred_by]`. The destination rides in the form body and survives
arbitrary intervening requests. `users/edit.html.erb` has three separate
`form_for @user` blocks and none of them carries the field.

Suggested shape:

```ruby
def follow_redirect(default_path, parameters = {}, notice = nil)
  target = params[:referred_by].presence || session[:referred_by]
  ...
end
```

with the hidden field added to the users and supervisors forms. The session
then becomes a fallback rather than the mechanism, and the one-hop rule stops
mattering. `redirect_user` collapses into a plain `follow_redirect`.

Two things to handle when doing it. `redirect_to params[:referred_by]` is an
**open-redirect shape** — user-supplied and unvalidated. It is currently gated
behind `require_login` so exposure is small, but propagating the pattern means
adding `only_path: true` or a whitelist. And
`RedirectTest#test_Does_not_use_expired_redirects` is **skipped** pinned to this
note: it asserts the current expiry semantics, so it should be rewritten to
assert the new behaviour rather than simply un-skipped.

<a name="system-coverage"></a>
**What the system tests now cover.** Thirteen tests, one skipped. The three
original files (login, employees index, redirect) were joined by:

- `payslip_history_test.rb` — the employee page → payroll history → reprocess
  path, which is the only payslip journey a user actually has.

  **`payslips/show.html.erb` is dead and should not be tested.** Every link in
  the app passes `format: :pdf` (`employee_history`, `process_all_employees`,
  `payslip_corrections/index`), and `process_employee_complete` redirects to
  the PDF as well, so the HTML branch is reachable only by hand-editing a URL.
  A first version of this test rendered it and claimed to be covering figures
  users see; it was not, and it would have kept a debug view on life support.
  The rendered figures live in the PDF, and `test/models/payslip_pdf_test.rb`
  already covers those. If that template is genuinely unused, deleting it is
  the better cleanup — see Open items.
- `employee_form_test.rb` — the only multi-attribute form post in the suite.
  Covers strong parameters, `form_for`'s url/method overrides and
  `date_select`'s multi-parameter attributes, none of which a controller test
  that hand-builds its params hash can see. Uses the `:personal` page on
  purpose: `employees.coffee` animates the wage and supervisor fields with
  jQuery `show('fast')`/`hide('fast')` on `turbolinks:load`, and neither
  `input[data-wage]` nor `select#employee_supervisor_id` is rendered by
  `_personal_form`, so those handlers match nothing and no animation runs.
  Check that before adding a test against any other employee page.
- `authorization_test.rb` — that `rescue_from AccessGranted::AccessDenied`
  actually redirects and the resulting flash reaches the layout. Integration
  tests stop at the response; only a rendered page shows the user sees it.
- `estimate_pay_test.rb` — the one UJS remote form in the app. Written after it
  was found broken; see below.

The two new GET-only files are stable; the form test inherits the dropped-
interaction problem above. Prefer GET-only targets when adding more, and check
`grep -rln "turbolinks:load" app/assets/javascripts/` before picking a page.

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
| Delete `app/views/payslips/show.html.erb` | nothing | Confirmed dead: every link passes `format: :pdf` and `process_employee_complete` redirects to the PDF, so the `format.html` branch is unreachable except by hand-editing a URL. Debug output, not a page. Agreed as worth removing, but **after** the upgrade ships — it is app change, and the 6.1 diff stays a pure upgrade. Removing it means dropping `format.html` from `PayslipsController#show` too. |

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

---

## Post-upgrade pass, on `develop`

Found while validating 6.1 by hand, but **not** caused by it — neither
mechanism depends on any 6.1 behaviour change. They belong on `develop` after
the upgrade ships, so the 6.1 diff stays a pure upgrade. Worth a 30-second
confirmation on `develop` before fixing, since that has not been done.

### 1. Editing a payslip correction with a blank amount returns a 500

Leave the CFA (or vacation days) box empty and save. The user gets an
exception, not the validation error they should see.

Traced end to end:

1. The text field submits `""`. ActiveRecord casts `""` to `nil` for an
   integer column, so `cfa` becomes `nil` — not `0`.
2. `validates :cfa, numericality: {only_integer: true}` has no `allow_nil`, so
   the record is invalid: `"Cfa is not a number"`.
3. `PayslipCorrectionsController#update` therefore falls to `render :edit`.
4. `_correction_form.html.erb:20` runs `@correction.cfa = @correction.cfa.abs`
   on the way back out — `NoMethodError: undefined method 'abs' for nil`.

Line 19 already guards nil for picking Credit/Debit; line 20 does not guard the
`.abs` directly beneath it. `vacation_days` has the identical pair at lines
28–29.

The fix is small but there is a decision in it: either treat a blank box as
zero (`allow_nil` plus a `before_validation` defaulting to 0) or require a
value (`presence: true`). Both are defensible and they behave differently for
someone correcting only vacation days, so ask before picking. Guard the `.abs`
either way — a view helper that renders sign and magnitude would remove the
mutation-during-render entirely, which is the real smell here.

### 2. A taxable misc payment with a negative amount breaks payslip processing

`MiscPayment` validates `amount` only as `numericality: {only_integer: true}` —
nothing constrains the sign. A negative taxable payment therefore saves fine
and detonates later, at processing time, far from where it was entered.

`Payslip#misc_pay` (`app/models/payslip.rb:707-710`) turns each
`before_tax: true` payment into `Earning.new(amount: ...)`. `Earning`'s
`has_valid_amount` returns false unless `amount > 0`, so a negative amount
satisfies none of amount/percentage/hourly-rate, the Earning is invalid, and
`Earning#total` raises `"Cannot total an invalid Earning"`.

Note `amount == 0` fails the same way (`amount <= 0`), so any fix should cover
zero too.

Only the taxable path is affected. `before_tax: false` payments become
`Deduction`s with `amount * -1`
(`app/models/payslip.rb:739-744`), where a negative simply becomes a positive
deduction — which is likely why this survived so long.

The obvious fix is a validation on `MiscPayment` rejecting non-positive amounts
for taxable payments. Confirm first that nobody is *relying* on entering a
negative taxable payment to mean a clawback; if they are, the fix belongs in
`misc_pay` (emit a `Deduction` for negative amounts) rather than in validation,
and existing rows need checking either way.

### 3. `app/models/bonus.rb` includes `NumberHelper` into `Object`

Line 1 of `app/models/bonus.rb` is a bare, top-level
`include ActionView::Helpers::NumberHelper` — outside the class body, so it
lands on `Object` and every object in the process gains `number_to_currency`,
`number_with_precision` and friends as soon as that file is loaded.

`EmployeeVacationReport#format_vacation_balance` calls `number_with_precision`
with no receiver and only works because of this.
`test/reports/integration/employee_vacation_report_test.rb` does not catch it:
`run_report` executes the compiled SQL directly and never touches the
formatters, so nothing in the suite renders this report's formatted output. Every other report goes
through `formatter.number_to_currency`, which is the supported path —
`Dossier::Formatter` includes `NumberHelper` on purpose.

This is not currently broken: models are eager-loaded in production, so `Bonus`
is always loaded before a request runs. It shows up under lazy loading —
`bin/rails runner` raises `NoMethodError: undefined method
'number_with_precision'` for the vacation report, and referencing `Bonus`
first makes it pass. So it is a load-order dependency, not a live defect, and
it is why this was left alone on the upgrade branch.

Two separate fixes: give `EmployeeVacationReport` the `formatter.` receiver the
other reports use, and move the `include` inside `class Bonus` where it was
presumably meant to go. Do the first one first — the second changes behaviour
for anything else that has quietly come to depend on the global.

### Also on the list

- Delete `app/views/payslips/show.html.erb` and the `format.html` branch of
  `PayslipsController#show` — see Open items.
- Rewrite `RedirectToReferrer` — see [the section above](#redirect-rewrite),
  which also unskips `RedirectTest#test_Does_not_use_expired_redirects`.
