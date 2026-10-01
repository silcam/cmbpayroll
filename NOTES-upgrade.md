# Upgrading cmbpayroll


**Updated 2026-10-01, post go-live.** The 6.1 cutover described below shipped successfully on 1-Oct-2026. This revision folds in and retires three files that are now redundant with this one: `upgrade-6.1-validation.txt` (the manual QA pass — complete, findings absorbed into [Post-upgrade pass](#post-upgrade-pass) below), `PLAYBOOK-go-live-6.1.md` (the day-of checklist — executed, its Appendix A is now [Privating the GitHub repo](#privating-the-repo) below), and `PLAN-rails8-roadmap.md` (the 7.0→8.x planning doc — now [Roadmap: 6.1 → 7.0 → 7.1 → 7.2 → 8.x](#roadmap) below). All three are being
deleted; nothing in them is lost.

Companion document: `NOTES-remove-dossier.md` (see [Dossier](#dossier) below).

---

## Where we are

Current state as of 2026-10-01, `master`/`develop`:

| | value |
| --- | --- |
| Ruby | 3.2.10 |
| Rails | 6.1.7.10 |
| `config.load_defaults` | 6.1 |
| Autoloader | zeitwerk |
| Test suite | 625 tests, green |
| Deployed to production | **yes — live since 1-Oct-2026** |

The remaining deprecation noise is `PG::Coder.new(hash)` from `pg 1.6.3`
against `activerecord 6.1` — gem version skew, not app code, and it clears
itself at Rails 7.1.

---

<a name="plan-from-here"></a>
## Plan from here: order of work

Decided 2026-10-01. This is the order to work through the open items below,
not a schedule — no dates attached, just sequence. Come back to this section
first when picking up the next piece of work.

1. **Cleanup pass for bugs pushed down the road.** The three issues found
   during the 6.1 upgrade and deliberately deferred to `develop` so the 6.1
   diff stayed a pure upgrade — see [Post-upgrade pass](#post-upgrade-pass):
   the payslip-correction blank-amount 500, the negative-taxable-misc-payment
   crash, and the `Bonus`/`NumberHelper` global `include`. Bundle in the other
   no-dependency items from [Open items](#open-items) while in there: merge
   `upgrade_app`/`master` into `develop` (needed regardless of what comes
   next), delete the stale debug notes in `app/models/user.rb`, delete
   `app/views/payslips/show.html.erb` and its dead `format.html` branch, and
   delete the superseded `rails-version-change` branch.
2. **Remove dossier.** See [Dossier](#dossier) and prerequisite item 2 in
   [Do these before starting the 7.0 branch](#before-70) — the pinned fork
   gets re-tested every hop for a dependency that's mostly unused, so cutting
   it loose now avoids paying that tax four more times.
3. **Private the GitHub repo.** See [Privating the GitHub repo](#privating-the-repo).
   Lowest urgency of the five — fine to delay past the others if something
   else needs the window first; nothing downstream is blocked on it except
   the CI secret-handling decision, which has other options.
4. **Bump Ruby past 3.2, as its own standalone hop.** See
   [Ruby version](#ruby-bump-decision) below — this settles the timing half of
   that question: a standalone hop, ahead of 7.0, not folded into the 7.0
   commit. Target version (3.4.9 or newer) not yet finalized.
5. **Start Rails 7.0, then progress hop by hop through the rest of the
   roadmap** (7.0 → 7.1 → 7.2 → 8.0 → 8.1). Before opening the 7.0 branch,
   work through whatever [prerequisites](#before-70) aren't already covered by
   steps 1–4 above — at minimum, CI needs to be live and gating, the
   `secrets.yml` → credentials migration should be done, and the
   `RedirectToReferrer` rewrite should land, since 7.0's
   `raise_on_open_redirects` default turns that from a latent note into an
   active risk.

---

## Release record: the 6.1 cutover (completed 1-Oct-2026)

What follows is the mechanics of how 6.1 actually shipped, kept as reference
for the next hop that moves Ruby (not expected before 7.0, possibly later —
see [Open decision: when to bump Ruby past 3.2](#ruby-bump-decision)). A
Rails-only hop (7.0, 7.1, 7.2, 8.0, 8.1) does **not** need the nginx /
`passenger_ruby` dance below at all, since the Ruby version isn't changing —
it only needs the ordinary `cap production deploy` + watch.

### What was wired up on the server (verified 2026-09-17, still true at cutover)

- Passenger 6.2.0, installed system-wide (`/usr/bin/passenger-config`), serving
  **two** apps on `tom`: `cmbpayroll` and `libarchives`.
- Ruby is selected **per app, per vhost**, by a versioned binary path — not a
  shim:
  - `/etc/nginx/sites-available/cmbpayroll.conf:21`
    `passenger_ruby /home/cmbpayroll/.rbenv/versions/3.2.10/bin/ruby;` (was
    `2.7.4` before the cutover)
  - `/etc/nginx/sites-available/libarchives.conf:9` → `2.6.10`, untouched by
    this cutover and confirmed unaffected afterward.
- `cmbpayroll`'s rbenv has 2.5.8, 2.6.10, 2.7.4 and 3.2.10 — all four kept,
  not just the active one, so a rollback target's `Gemfile.lock` always has an
  interpreter to resolve against.
- The Ruby pin lives in `Capfile` (`set :rbenv_ruby, '3.2.10'`, `set
  :rbenv_type, :user`), and takes effect only once it's on whatever branch
  `config/deploy.rb`'s `set :branch, 'master'` points the deploy at — it rides
  the merge to `master`, it is not a separate server-side step.

### Bundler coexistence — done 2026-09-17, keep both generations

`Gemfile.lock` on the 6.1 branch is `BUNDLED WITH 4.0.11` (bundler-4 `sha256=`
checksum format). 3.2.10 shipped with only its default bundler 2.4.19, so
`gem install bundler -v 4.0.11` was run under 3.2.10 on `tom` ahead of time.

**Do not remove bundler 2.1.4 from the 2.7.4 rbenv install.** Both generations
must coexist indefinitely: 2.1.4 is what the pre-6.1 release's lockfile
resolves with, and bundler 4.x does not run on Ruby 2.7.4 at all. Removing
either breaks rollback silently. This applies to every future Ruby version
installed alongside the others going forward, not just this one pair.

### Cutover sequence actually used

1. Ruby 3.2.10 + bundler 4.0.11 installed on `tom`'s `cmbpayroll` rbenv —
   2026-09-17.
2. Throwaway boot test under 3.2.10 (scratch clone, `bundle install`,
   `RAILS_ENV=production bin/rails runner 'puts Rails.version'`) — verified ok
   28-Sep-2026. This is what turned "no native-extension recompile needed"
   (`pg`, `bigdecimal`, `prawn`, `sassc`) from an inference into an
   observation before the window, rather than a surprise during it.
3. nginx edit staged in advance, not applied — confirmed scoped to
   `cmbpayroll.conf` only, `libarchives.conf` untouched — ready 28-Sep-2026.
4. Unprivileged restart confirmed (`passenger-config restart-app
   /var/www/cmbpayroll/current` as the `cmbpayroll` user, no sudo needed) —
   verified ok 28-Sep-2026.
5. Day of, in order:
   1. Final local checks green (suite, zeitwerk, `ruby -c production.rb`,
      `upgrade_app` 0 commits behind `develop`) — verified 30-Sep-2026.
   2. Merge `upgrade_app` → `master`, push — complete 1-Oct 11:59 ET. This is
      what put `Capfile`'s `rbenv_ruby 3.2.10` in front of the deploy.
   3. Root staged the nginx edit on `tom`, typed and ready, not yet applied —
      complete 1-Oct 12:01 ET.
   4. `cap production deploy` — complete 1-Oct 12:16 ET. `bundle install`,
      asset precompile and `deploy:migrate` (confirmed a no-op below) all ran
      *before* the `current` symlink flipped, so a failure there would have
      aborted safely with the old release still serving traffic under 2.7.4.
   5. Root saved the nginx edit and reloaded — complete 1-Oct 12:17 ET. The
      ~1-minute gap between steps 4 and 5 was the entire outage: from the
      moment `cap` flipped `current` and restarted Passenger, the app 500'd
      under the old `passenger_ruby` (2.7.4 can't boot a release built for
      6.1's config) until the reload took effect.
   6. Verified clean: app loads and logs in, `passenger-status` shows it
      running (Ruby version itself isn't visible there, but confirmed via the
      nginx config line directly — equivalent confirmation), unprivileged
      restart still works post-cutover, `libarchives` unaffected, a real
      payslip PDF rendered correctly. **No rollback needed.**

### Why the database needed no rollback plan of its own

`Capfile` requires `capistrano/rails/migrations`, so `cap` always runs
`deploy:migrate` — but the 6.1 diff added no migrations (`git diff
develop..upgrade_app -- db/` touched only `db/schema.rb`'s header comment and
6.1's underscore-formatted version string; the version number itself was
unchanged). So `deploy:migrate` was a no-op, and rollback (if it had been
needed) would have been exactly: revert the nginx line to `2.7.4`, reload,
`cap production deploy:rollback` — both halves required, neither alone
sufficient. **This stops being true the moment a real migration ships on a
future hop** — re-derive the rollback story per-hop rather than assuming this
one still applies.

### Still to watch

The cookie/CSRF/session wire-format settings enabled on this branch
(`action_dispatch.cookies_same_site_protection`, authenticated cookie
encryption, etc.) only manifest against *real* existing sessions, and the
cutover was the first time any of that ran against production traffic. Keep
watching logs for a few hours/days past the cutover, not just the first few
minutes — a user who was logged in before the cutover needing to log in again
is expected, not a bug, but confirm fresh logins work cleanly. This same
caveat applies to every future hop too (see [Principles](#principles) below).

---

## CI — written, validated, parked on `ci-github-actions`

The workflow exists and was validated end-to-end, but it is **not on this
branch** (and was not restored for the 6.1 cutover). It lives on
`ci-github-actions`, a bookmark taken off `upgrade_app` at `82e0ebf`. Restore
it with:

    git checkout ci-github-actions -- .github/workflows/ci.yml

That works however far the branch moves on, which is why the workflow was
parked on a branch rather than reverted, and why recovery is a `checkout` and
not a merge. `046d24b` and `ae9e440` stay in history; only the file is gone.
`046d24b` also added the explanatory comment above `db/wages.sql` in
`.gitignore` — that comment stays, because it is policy, not CI.

Parked on purpose. Switching it on needs decisions that are not upgrade
decisions (see [What is still undecided](#ci-undecided)), and running the
suites locally was sufficient through the 6.1 release. The cost of the delay
is that the workflow has still **never run on GitHub** — expect to iterate on
the first couple of runs whenever it does land. This decision is now more
urgent than it was before 6.1 shipped — see the [7.0 prerequisites](#before-70)
below.

### Why it is worth coming back to

Every systemic problem the 6.1 upgrade cost us was CI-shaped:

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

    bin/rails test              # 625 tests
    bin/rails zeitwerk:check    # eager loads everything, incl. lib/
    RAILS_ENV=production bin/rails runner '...'   # actually loads production config

`ruby -c` is what caught the duplicate `end`, but it only catches syntax, not a
runtime config error. Booting the production environment catches both. It needs
`SECRET_KEY_BASE` (test self-generates one; production does not) and a
`DATABASE_URL`, because the production section of `database.yml` carries no
credentials — they live on the server as a Capistrano linked file.

`bin/rails test:system` runs in a separate **non-gating** job; see
[Flakiness](#flakiness) for why, and what would let it become gating.

### The `db/wages.sql` problem

This is the reason the workflow is parked rather than running.

`db/wages.sql` is deliberately never committed, but `db/seeds.rb` reads it and
`test/test_helper.rb` loads seeds at require time — so on a fresh clone, which
is exactly what CI is, **every test fails before the first assertion**. That
now includes the report-rendering tests, which go through
`return_valid_employee` and `Payslip.process`; the file is load-bearing for far
more than the money-verification tests.

As parked, the workflow rebuilds it from a GitHub Actions secret:

    gzip -9 -c db/wages.sql | base64 -w0 | gh secret set WAGES_SQL_GZ_B64

~2 KB encoded, against a 48 KB limit; the round trip is verified
byte-identical. **`gzip | base64` is encoding, not encryption** — it exists
only to flatten a 22 KB multi-line file into a single-line secret value, and
anyone holding the string recovers the file with a one-liner. The
confidentiality is entirely GitHub's secret store (encrypted at rest, decrypted
into the runner at workflow time) and the access control on it. Two further
things to keep in mind:

- **This repo is public, so its build logs are public.** A failing test prints
  real wage figures (`Expected: 42010`). GitHub masks the secret's own string
  in logs, but the workflow decodes it to a file, and the decoded figures are
  not masked. Separately, 22 of the 120 distinct basewage figures are already
  in tracked files — e.g. `wage_test.rb:92` asserts `42010`, and one test is
  *named* `test_Test_Payslip_72474`.
- **Fork PRs receive no secrets**, so that step fails there by design.

<a name="ci-undecided"></a>
### What is still undecided

Four ways out:

1. **The Actions secret**, as parked above.
2. **A committed synthetic wages file.** Measured: 558 of 588 tests still pass
   — the 30 that fail are the money-verification ones in `payslip_test`,
   `vacation_test`, `employee_test`, `wage_test`, `tax_test`.
3. **A self-hosted runner** (`cp` the file in). GitHub advises against this on
   public repos, since a fork PR can run code on the machine.
4. **Making the repo private**, after which the file can simply be tracked —
   see [Privating the GitHub repo](#privating-the-repo) below, which is this
   option worked out in full.

Option 4 is the cleanest end state and was not available when the project
started. Whatever is chosen, the GitHub-side work is: create the secret (if
option 1) **before** pushing, since `on: push` has no branch filter and the
first push triggers a run whose failure would be a public log; confirm
Actions is enabled on the repo; and add `Unit & integration tests` as a
required check only after it has run once. The system-test job is
`continue-on-error: true`, so it cannot block a merge either way. Dependabot
needs the secret in its own separate store, but only once the workflow reaches
`develop` — `pull_request` resolves the workflow from the base ref, so a
workflow on a topic branch never runs for those PRs.

---

<a name="privating-the-repo"></a>
## Privating the GitHub repo (planned, not yet done)

Carried forward from `PLAYBOOK-go-live-6.1.md`'s Appendix A, written
2026-09-28. **Not done as part of the 6.1 cutover, on purpose** — it touches
the deploy mechanism itself (below), and that shouldn't be debugged in the
same window as a Rails/Ruby version change. Do it once 6.1 has been stable for
a few days, and before the CI decision above is acted on, since this *is*
option 4 of that decision.

### Why, and why it's safe

`cmbpayroll` is a public GitHub repo containing real Cameroon payroll wage
data ready to be tracked (`db/wages.sql`, currently gitignored precisely
*because* the repo is public) and, separately, real taxpayer identifiers
(`db/load_niu.sql`). Making the repo private removes the reason
`db/wages.sql` has to stay out of git, and removes the concern above that a
failing CI test on a public repo prints real wage figures into a public build
log.

Re-verified clean 2026-09-28:

    git log --all --oneline -- db/wages.sql db/load_niu.sql
    # (no output — neither file has ever been committed, on any branch, ever)

So there is nothing to scrub from history. This is a green light for
privating the repo without any BFG/filter-repo history surgery.

**Not retroactive, one caveat:** if anyone has forked this repo, flipping
visibility splits existing public forks into their own separate network —
their forks stay public and independent, they just stop tracking this repo.
Check `Settings → General → Danger Zone` or the repo's fork count before you
flip, so this isn't a surprise to a collaborator.

### Fix the deploy mechanism first — it currently depends on the repo being public

This has to change **before** visibility flips, not after, because a private
repo breaks it immediately:

- `config/deploy.rb` — `set :repo_url, "https://github.com/silcam/cmbpayroll.git"`.
  Anonymous HTTPS. Works today only because the repo is public; a private repo
  answers this URL with a 404/auth prompt and every future `cap production
  deploy` fails at the fetch step.
- `set :deploy_via, :remote_cache` means the server keeps its own persistent
  clone (under `shared/cached-copy` by convention) pointed at that same URL —
  that cached clone needs repointing too, not just the config.
- `config/deploy/production.rb` sets `forward_agent: false` explicitly in
  `ssh_options` for the *deploy user's* connection to `tom` — unrelated to
  which git protocol the server itself uses to fetch, but worth knowing this
  was already set deliberately, not an oversight, so don't "fix" it while in
  this file for the other reason.

**Fix, in order:**

1. Generate a **read-only deploy key** dedicated to this server:

       ssh cmbpayroll@tom
       ssh-keygen -t ed25519 -f ~/.ssh/cmbpayroll_deploy_key -N ""
       cat ~/.ssh/cmbpayroll_deploy_key.pub

2. Add that public key on GitHub: repo → **Settings → Deploy keys → Add deploy
   key** — leave "Allow write access" unchecked, this only needs to fetch.
3. Point the server's SSH config at it (e.g. `~/.ssh/config` for the
   `cmbpayroll` user on `tom`, a `Host github.com` block with
   `IdentityFile ~/.ssh/cmbpayroll_deploy_key`), or configure it however this
   server's existing SSH setup expects a per-host key.
4. `config/deploy.rb` → `set :repo_url, "git@github.com:silcam/cmbpayroll.git"`.
   (Note the local dev clone's own `origin` remote is already this form —
   only the *server's* deploy config uses the anonymous HTTPS URL.)
5. On `tom`, delete or repoint the existing remote-cache clone so it doesn't
   try to fetch from the old URL on the next deploy:

       rm -rf /var/www/cmbpayroll/shared/cached-copy

   (Capistrano recreates it on the next `cap production deploy` using the new
   `repo_url`.)
6. **Verify while still public.** Commit the `deploy.rb` change, deploy it,
   and confirm `cap production deploy` still succeeds end to end — the SSH
   deploy key works identically whether the repo is public or private, so
   this is fully testable before touching visibility at all. Do not flip
   visibility until a clean deploy over the new URL has been seen.

### Check GitHub Actions billing, if turning CI on around the same time

Public repos get unlimited Actions minutes; private repos draw from the
org/account's plan quota. The parked `ci-github-actions` workflow has no
branch filter on `on: push` across its two jobs, one of which boots headless
Chrome for the system-test job — check **Settings → Billing** before this
combination goes live on a private repo, and add a branch filter as the cheap
mitigation if quota is a concern. This only matters if/when the CI decision
above is acted on — it does not block privating the repo by itself.

### Flip visibility

Repo → **Settings → General → Danger Zone → Change repository visibility →
Make private.** GitHub requires typing the repo's full name to confirm — this
is deliberately not a casual click.

- [ ] Confirm the deploy-key fix above is already deployed and verified
      (step 6) before doing this.
- [ ] Confirm nobody has a PR open against a fork that they'd lose track of
      (see the fork-splitting caveat above).
- [ ] Do it.
- [ ] Immediately after: run one more `cap production deploy` (even a no-op
      one, e.g. redeploy the current commit) to confirm the deploy key path
      still works against the now-private repo. This should be a formality
      given the pre-verification above, but it's the one thing that's
      genuinely different once the repo is actually private rather than being
      tested against a public repo with a private-style credential.

This step is reversible on its own (flipping back to public is just the same
setting in reverse) — it's a GitHub setting, not a git-history change. What's
*not* casually reversible is the next step, once acted on.

### Now that it's private — clean up the reason `db/wages.sql` was ever gitignored

This is optional and can be done same-day or later, but it's the payoff
called "the cleanest end state" above:

- [ ] Remove `db/wages.sql` from `.gitignore`.
- [ ] `git add db/wages.sql && git commit`. From this point the file travels
      with the repo like any other seed data, and every future clone/CI
      checkout has it — no more per-environment "where does this file come
      from" step.
- [ ] Leave `db/load_niu.sql` gitignored regardless. Real taxpayer identifiers
      keyed to employee ids are a higher bar than a wage table even in a
      private repo, and nothing reads it through `seeds.rb`, so tracking it
      buys nothing.
- [ ] If/when the parked CI workflow is restored, drop the
      `gzip | base64` → GitHub Actions secret round-trip for `db/wages.sql`
      entirely — the file is just present in the checkout now, so the
      workflow gets simpler, not just safer.

**This step is the one that isn't casually reversible.** Once `db/wages.sql`
is committed, making the repo public again later means real wage figures are
in git history permanently (history rewrite would be needed to remove them).
Treat privating and tracking the file as a one-way pair: don't track it unless
confident the repo is staying private.

---

<a name="roadmap"></a>
## Roadmap: 6.1 → 7.0 → 7.1 → 7.2 → 8.x

**Reference only — not a commitment to a schedule.** Originally written
2026-09-30 as a separate document the week 6.1 went live; folded in here
2026-10-01 now that 6.1 has actually shipped. Re-verify every version-specific
claim below against the actual Rails upgrade guide and the installed
gemspec's `load_defaults` case statement *at the time each hop starts* — this
section can drift out of date faster than the app does, especially anything
said about 8.1/8.2, which are newer than most of what informed this plan.

**No further Ruby upgrade is needed to reach Rails 8.1.** Verified against
published gemspecs: Rails 7.0/7.1 require Ruby `>= 2.7.0`, 7.2 requires
`>= 3.1.0`, and 8.0/8.1 require `>= 3.2.0`. Ruby 3.2.10 already clears all of
them. This is the single biggest simplifier versus the 5.1→6.1 hop, which had
to move Ruby and Rails at once — every hop below is a Rails-only change. A
Ruby bump past 3.2 is planned anyway, for EOL reasons rather than any Rails
requirement — see [Ruby version](#ruby-bump-decision) below, decided to run
as its own standalone hop ahead of 7.0, not tied to any Rails hop's commit.

### Sequencing: yes, 7.0 before 8.0 — go through every hop, don't skip

Worth being explicit about: the recommendation is to get **each Rails minor
onto production before starting the next one** — 6.1 → 7.0 → 7.1 → 7.2 → 8.0
→ 8.1, one hop at a time. Not a single branch that jumps from 6.1 straight to
8.x, and not skipping any individual minor in between.

Why: this is the same lesson the 5.1→6.1 upgrade already paid for once, the
hard way. That upgrade skipped Rails 6.0 and Ruby 3.0/3.1 entirely (5.2 → 6.1
and 2.7.4 → 3.2.10 in one commit), and that's why regressions were so hard to
root-cause — every failure had two candidate explanations. Jumping from 6.1
straight to 8.x would compound that same problem across *four* skipped minors
(7.0, 7.1, 7.2, plus whatever's genuinely new at 8.0) instead of two. Each hop
carries its own `config.load_defaults` transition and its own
`new_framework_defaults_X.rb` file to walk setting by setting; 7.2
specifically carries a hard blocker (`secrets.yml` removal) that needs to be
dealt with on its own terms, not discovered three versions deep into a bigger
jump.

It also means each intermediate version — 7.0, 7.1, 7.2, 8.0 — genuinely runs
in production for a while, not just as a stepping-stone branch merged and
immediately superseded. That's deliberate: the "ship before continuing"
principle below is what makes the cookie/CSRF/session wire-format settings
safe to trust — each hop's settings need a real deploy-and-watch against live
traffic, which only happens if that version actually stays live for a stretch
before the next hop starts.

<a name="ruby-bump-decision"></a>
### Ruby version: decided to bump past 3.2 as its own standalone hop, before 7.0

**Timing decided 2026-10-01** (see [Plan from here](#plan-from-here) above):
do this as its own standalone hop — its own branch, its own deploy-and-watch
window — **ahead of** opening the 7.0 branch, not folded into the 7.0
commit as this section originally proposed as a default. **Target version not
yet finalized** — leaning 3.4.9 over 3.3.x per the reasoning below, but check
whether anything newer (a later 3.4 patch, or 3.5 if it's shipped by the time
this is executed) is the better target when this is actually scheduled.

Ruby 3.2's series reached end-of-life 2026-04-01 (confirmed against
ruby-lang.org's maintenance branches page), so it's already been unsupported
for months — exposure that shouldn't keep riding behind whatever else is
queued ahead of the 7.0 branch. Nothing in the Rails roadmap above *forces*
moving off 3.2 — 8.0/8.1 only require `>= 3.2.0` — so this was purely a
standalone risk/scheduling call, not a version-compatibility one.

Why a standalone hop rather than riding along with 7.0: a Ruby-only change
carries no Rails-side content, so it's the cheapest hop on this whole
roadmap — full suite, `zeitwerk:check`, native-gem rebuild, a throwaway boot
test (same pattern as the 6.1 cutover's server-prep step, see the release
record above), one deploy, one short monitoring window, done. Doing it first
and separately, rather than bundled into 7.0, keeps a regression attributable
to the right change if either hop turns something up — the same reasoning
behind "one Rails minor per branch" in [Principles](#principles) below
applies just as much to not bundling a Ruby change in with a Rails change.

- **Why this is safer than the original 2.7→3.2 double jump was:** that jump
  crossed Ruby's keyword/positional-argument split — the single most
  disruptive Ruby language change in a decade, and the actual source of most
  bugs the 6.1 upgrade found (`Vacation#save`, the `assert_*_permission`
  helpers). Ruby 3.2 → 3.4 crosses no comparable fault line. The known
  3.4-specific changes are already small: `Hash#inspect` format (only matters
  to code asserting on inspected output — the one place that did,
  `payroll_audit.rb`, is already slated for deletion per the Open items
  below), frozen-string-literal warnings (not yet enforcement), and further
  default-gem trimming (same shape as the `net-smtp` move already handled at
  Ruby 3.1).
- **Target version, if 3.4: lean 3.4.9 over 3.3.x.** 3.3 only buys support
  until 2027-03-31 — not much further out than doing this again soon — while
  3.4's EOL isn't set yet, so the native-extension and behavior-diff work
  only needs doing once for a longer payoff. Re-check at execution time
  whether a newer target makes more sense.

Mechanically, whenever it happens: install the target version in `tom`'s
rbenv alongside the existing versions — keep 3.2.10 in place, same rollback
discipline the 6.1 cutover already established (don't remove an old
interpreter that a rollback target's `Gemfile.lock` might still need) — and
reuse the throwaway-boot-test pattern from the release record above before
cutting over.

<a name="before-70"></a>
### Do these before starting the 7.0 branch, not during it

Doing these first turns "6.1 → 7.0" into an ordinary one-variable hop instead
of a repeat of the double-jump problem that made the 5.1→6.1 upgrade so hard
to debug. None of them are forced by Rails 7.0 itself — they're forced by
*not wanting a second confounded change* while diagnosing whatever 7.0 does
turn up.

1. **CI must be live and gating before this starts.** The whole reason the
   parked `ci-github-actions` workflow matters more now than it did for the
   6.1 hop: `upgrade_app` had no production traffic to protect and could
   afford to discover the Yoda-fixture-class of bug by hand. The next four
   hops will be edited against a codebase that *is* in production. Resolve
   the `db/wages.sql` question ([above](#ci-undecided), or
   [Privating the GitHub repo](#privating-the-repo)) and get `Unit &
   integration tests` set as a required check before opening a `7.0` branch.
2. **Remove dossier first.** `NOTES-remove-dossier.md` (on
   `remove-dossier-plan`, commit `09cdac2`) found that almost nothing dossier
   actually provides is used — gem routes disabled, `Dossier::ReportsController`
   unused, the responder dead code, PDF rendering is thinreports not dossier.
   It's pinned to a SHA on an unmaintained fork (`cetuslabs/dossier`) because
   the last real release depends on `arel`, which Rails 6.0 absorbed. Every
   future hop re-tests a fork nobody maintains for a dependency that's mostly
   unused; cut it loose before paying that tax four more times.
3. **Migrate `config/secrets.yml` to Rails encrypted credentials now, not at
   the 7.2 deadline.** This is valid on Rails 6.1 today — `credentials.yml.enc`
   has existed since 5.2 — so doing it early is free optionality, not a
   version-forced change yet. Doing it now, on a branch with no other Rails
   version change in flight, means the 7.2 hop (where `secrets.yml` is
   *removed*, see below) has nothing left to do. Concretely:
   - `grep -rn "Rails.application.secrets" app/ config/ lib/` — right now this
     is at minimum `config/secrets.yml`'s `secret_key_base`, and it will also
     be every SMTP setting the audit-email-notifications plan wants to add
     (`PLAN-audit-email-notifications.md` §8, `Rails.application.secrets.smtp_*`,
     `mail_from`, `mail_host`) if that plan lands before this migration does —
     check which landed first.
   - `bin/rails credentials:edit` to create `config/credentials.yml.enc` +
     `config/master.key`, carrying over every value from `secrets.yml`.
   - Deployment half: `config/master.key` replaces `config/secrets.yml` as the
     Capistrano linked file (`config/deploy.rb`,
     `append :linked_files, "config/secrets.yml"` → `"config/master.key"`).
     The key has to exist on `tom` before the first deploy that reads
     credentials instead of secrets — this is exactly the kind of
     deploy-and-code pairing the 6.1 cutover already had to think through once.
   - Read every value through one accessor rather than
     `Rails.application.credentials.dig(...)` scattered through
     `production.rb` — `PLAN-audit-email-notifications.md`'s `MailSettings`
     class (§A.6.2) already assumed this would happen and is written to make
     the swap a one-file edit.
4. **Consider the `RedirectToReferrer` rewrite before 7.0, not after.** The
   [`#redirect-rewrite`](#redirect-rewrite) section below already flags
   `redirect_to params[:referred_by]` as "an open-redirect shape... currently
   gated behind `require_login` so exposure is small." Rails 7.0's
   `config.load_defaults 7.0` turns on
   `config.action_controller.raise_on_open_redirects = true` by default, which
   makes `redirect_to` **raise `ActionController::Redirecting::UnsafeRedirectError`**
   for a redirect to a bare, unvalidated path unless it's provably same-host.
   Depending on how `params[:referred_by]` is shaped when this actually fires,
   this could turn a latent security note into an active 500 the day
   `load_defaults` gets bumped to 7.0 — worth writing the rewrite (which
   already has a suggested shape in that section, and already plans to add
   `only_path: true` / a whitelist) while it's a design choice rather than a
   fire.
5. **Grep for `form_with` again before every hop, not just this one.** The
   generalisable lesson from the `/admin/estimatepay` regression (below):
   "options that Rails silently ignores are invisible until a default flips."
   Cheap insurance, five seconds, do it every time.

None of items 2–4 are Rails-7.0-specific — they're just easier to do on a
branch with nothing else changing. If schedule pressure means they don't all
happen first, at minimum do CI (item 1) first; the other three can ride along
*inside* the 7.0 branch instead, at the cost of one more confound if
something breaks.

### The per-hop checklist (repeat this shape four to five times)

This is [Principles for the remaining hops](#principles) below, restated as
steps rather than lessons:

1. Branch from `develop` (which is now 6.1, post-merge) — `git checkout -b
   rails_7_0 develop`, one Rails minor only. Do not also move Ruby; nothing
   below needs it (see the hop-by-hop table).
2. Bump the `Gemfile` constraint (`gem 'rails', '~> 7.0'`), `bundle update rails`,
   run `bin/rails app:update` and accept new initializer templates
   (`new_framework_defaults_7_0.rb` etc.) without enabling anything yet.
3. Fix whatever fails to *boot* first — gem incompatibilities, removed APIs —
   before touching a single framework default. Get to a green `bin/rails test`
   with `config.load_defaults` still at the *previous* version.
4. Walk the new `new_framework_defaults_X.rb` file setting by setting, same as
   the 6.1 hop did for 5.2/6.0/6.1: enable one, run the suite, commit, repeat.
   Read the settings out of the installed railties gem's `load_defaults` case
   statement if the shipped template is thin or stale for a version being
   partially skipped.
5. **Cookie/CSRF/session settings need a real deploy-and-watch, not just a
   green suite, now that this app is in production.** This is the one thing
   that was actually *easier* for the 6.1 hop than it will be from here on:
   `upgrade_app` could flip all five deferred wire-format settings at once
   because nothing was deployed from it yet (principle 4 below). Every hop
   from here on runs against real existing sessions. Enable those settings,
   deploy, and watch logins/session survival for real traffic for a few hours
   before calling the hop done — the same caution applied to the 6.1 cutover
   itself (see "Still to watch" above).
6. Only once every individual setting is enabled and verified, bump
   `config.load_defaults` to the new version and delete the now-redundant
   `new_framework_defaults_*.rb` files.
7. `bin/rails zeitwerk:check`, `ruby -c config/environments/production.rb`,
   `grep -rn "form_with" app/views/` — the three-line insurance policy, every
   time.
8. Ship it: merge to `develop`, then to `master`, deploy, watch, *then* start
   the next branch. The hardest lesson from the 5.1→6.1 hop applies just as
   much here — a long-lived parallel branch collects divergence cost every
   week it isn't merged.

### Hop by hop: what's actually known about each one

| Hop | Ruby floor | Forced for this app | Known content |
| --- | --- | --- | --- |
| 6.1 → 7.0 | 2.7.0 (already have 3.2.10) | Nothing yet identified as a hard blocker | See below |
| 7.0 → 7.1 | 2.7.0 | Nothing | Mostly quiet; clears the `PG::Coder` noise |
| 7.1 → 7.2 | 3.1.0 (have it) | **`config/secrets.yml` removal** | See below — do the credentials migration *before* this hop if not done already |
| 7.2 → 8.0 | 3.2.0 (have it) | Nothing yet identified | Biggest hop in terms of new defaults; nothing forces adopting them |
| 8.0 → 8.1 | 3.2.0 | Nothing yet identified | Newest; re-verify, this plan is thinnest here |
| 8.1 → 8.2 | unknown | unknown | **May not exist yet as a released version — check before planning this far** |

#### 6.1 → 7.0

- **Turbolinks → Turbo becomes the default for *new* apps; not a forced
  migration for this one.** `turbolinks` 5.2.1 keeps working on Rails 7 (it's
  a plain gem dependency, not a framework-coupled feature). This app has 12
  `.coffee` files and multiple views wired to `turbolinks:load` — leave it,
  it's already on the "debt with no deadline" list below.
- **`raise_on_open_redirects` — see prerequisite item 4 above.** The single
  most concrete new risk this hop introduces for this specific app.
- **`errors[]` returning a copy** — already fixed on `develop` in `846ce47`
  ("Use the forward-compatible ActiveModel::Errors API"), so this hop
  shouldn't rediscover it; just confirm the fix still holds once
  `load_defaults` actually reaches 7.0 (the fix works under both, but the
  *old* behavior it replaced only breaks under 7.0's actual API removal, not
  under 6.1 where both still worked).
- **Encrypted attributes (`encrypts`) become available** for
  `ActiveRecord::Base` — optional, not required. Worth a look for `wage`,
  `cnps`, `dipe`, `niu` (the same four fields `PLAN-audit-email-notifications.md`
  already calls `SENSITIVE_FIELDS`) *if* there's ever a compliance reason to
  encrypt at rest, but nothing forces it and it's a real behavior change
  (transparent encrypt/decrypt, queryability changes) — a separate decision,
  not a byproduct of the version bump.
- **Sprockets is no longer the default for new apps (Propshaft is optional,
  not mandatory)** — this app's `sassc-rails`/`sprockets-rails` combination
  keeps working unmodified. Already "not on the critical path"; nothing
  changes this hop.
- **`audited` 5.8.0 (current) is already new enough** — no gem bump forced
  here specifically for Rails 7.0.

#### 7.0 → 7.1

- **Clears the `pg 1.6.3` / `PG::Coder.new(hash)` deprecation noise** —
  confirm it's actually gone rather than just assuming.
- **`config/secrets.yml` becomes *deprecated*** (removed at 7.2, not yet). If
  the credentials migration (prerequisite item 3) hasn't happened yet, this
  is the last hop where it's optional rather than urgent — do it here at the
  latest.
- **`config.autoload_lib(ignore: %w(assets tasks))` becomes the generator
  default** for new apps' `lib/` autoloading. This app already hand-rolled
  `lib/` into `eager_load_paths` during the zeitwerk adoption (see Landmines
  below) — worth comparing the two approaches once at this hop, but the
  existing setup already passes `zeitwerk:check` clean, so this is a "nice to
  align with the new idiom," not a fix.
- No other app-specific risk identified yet for this hop; historically the
  quietest of the five.

#### 7.1 → 7.2

- **`config/secrets.yml` is removed outright.** If prerequisite item 3 (or the
  7.0/7.1 fallback above) already migrated everything to credentials, this
  hop needs nothing further here. If it hasn't, **this is a hard blocker** —
  `secrets.yml` is a Capistrano linked file, so the migration to credentials
  or ENV has a deployment half as well as a code half. Don't discover this at
  the 7.2 branch; discover it at the prerequisite step above, where there's no
  version-bump pressure attached to it.
- Ruby floor moves to 3.1.0 — already satisfied by 3.2.10, no action.

#### 7.2 → 8.0

The largest hop in terms of what Rails *offers*, and — as of this writing —
the one with no known blocker in this app yet. Nothing below is forced; each
is an opportunity worth a deliberate yes/no, not a silent adoption:

- **Solid Queue becomes the default ActiveJob adapter for new apps.** This app
  has never had a durable job queue — `ActiveJob` is still the in-process
  `:async` adapter (confirmed as of the audit-email-notifications planning
  pass). Adopting Solid Queue is optional for an *existing* app, but it's the
  single biggest unlock on this whole roadmap: `PLAN-audit-email-notifications.md`
  §A.5 already designed around exactly this — "Immediate" notification
  frequency currently means "next 15-minute cron tick" specifically because
  there's no durable queue; with Solid Queue, `deliver_later` becomes durable
  and "Immediate" can become genuinely immediate, while the weekly/bi-weekly
  dispatcher and the watermark-based dedupe design carry over completely
  unchanged (that plan's §A.6 built the dispatcher as a PORO with one entry
  point precisely so this swap is a wrapper class, not a rewrite). Evaluate
  this at the same time as whatever email-notification work has landed by
  then, not in isolation.
- **Solid Cache / Solid Cable** — same shape, no current usage of either
  Redis-backed feature in this app to migrate, so this is closer to "nothing
  to do" than "an opportunity," but confirm there's really no `Rails.cache`
  usage worth moving before assuming that.
- **Kamal 2 becomes the default deploy tool for new apps.** This app deploys
  via Capistrano to a single server (`tom`) and nothing forces a change —
  Capistrano keeps working on Rails 8 apps. A Capistrano→Kamal migration is a
  much larger, separate decision (containerizing the app, changing the whole
  deploy model) and is explicitly **out of scope for this roadmap** — it's an
  infrastructure choice, not something Rails 8 requires.
- **The authentication generator (`bin/rails generate authentication`)** is
  new-app scaffolding; this app already has its own `User`/session model and
  `access-granted` policy layer — nothing to adopt here.
- Propshaft becomes the new-app default; sprockets still fully supported,
  same "not on the critical path" status as every prior hop.

#### 8.0 → 8.1

Thinnest section on this page, by design — no known blocker in this app yet,
and that was assessed closer to 8.1's release than this is to 8.1 becoming
relevant here. **Re-derive this section from the actual Rails 8.1 upgrade
guide when you get here** rather than trusting anything specific below:

- Ruby floor stays 3.2.0 — no Ruby action needed.
- No gem in this app's `Gemfile` is known to require an 8.1-specific bump.
- Re-run the same "walk `load_defaults`, then bump it" procedure regardless —
  there will be an `new_framework_defaults_8_1.rb`-shaped file even if this
  section doesn't yet know what's in it.

#### 8.1 → 8.2

Not attempted here. As of 2026-09-30, current latest was 8.1.3.1 — Rails 8.2
may not exist yet as a released version. **Before treating this as a real
hop, confirm 8.2 has actually shipped** and pull its upgrade guide fresh;
nothing about it is knowable in advance from here.

### Gems worth re-checking at every hop, not just once

Pulled directly from this app's `Gemfile`/`Gemfile.lock`, because a
version-compatibility surprise from one of these is a more likely failure
mode than anything in Rails itself:

| Gem | Current | Watch for |
| --- | --- | --- |
| `pg` | 1.6.3 | Already tracks Rails 6.1 fine; re-check each hop, this is the native-extension gem most likely to need a bump alongside a Rails major |
| `bigdecimal` | pinned 3.3.1 | Pinned deliberately — re-check whether the pin is still needed each hop, it was fixing a specific 6.1-era decode behavior (the DIPE filing fix, `cdbaaa0`) |
| `audited` | 5.8.0 | Already satisfies Rails 8's `>= 5.8` floor per earlier research; re-confirm each hop anyway |
| `dossier` | pinned fork SHA | Should be **gone** before 7.0 per the prerequisite above; if it isn't, this is the single riskiest gem on the list, since it's an unmaintained fork depending on `arel`, which Rails absorbed at 6.0 |
| `turbolinks` | 5.2.1 | No forced change; confirm it still boots each hop, since it's unmaintained upstream |
| `coffee-rails` / 12 `.coffee` files | 4.2.2 | Depends on `execjs`/a JS runtime; unmaintained but not forced to move — same "debt with no deadline" status every hop |
| `sassc-rails`, `sprockets`, `sprockets-rails` | current | Sprockets keeps working through 8.x; no forced Propshaft move |
| `jquery-rails`, `bootstrap-sass` | 4.3.5 / 3.4.1 | No forced change; both are old but inert |
| `capistrano` family | `~> 3.9` in `Gemfile`, resolves to 3.20.0 | Deploy tooling, orthogonal to the app's Rails version — only touch this if the server-side plan changes (e.g. Kamal), not because of a Rails bump. **See the Capfile-lock landmine below** — `Capfile`'s own `lock` string drifted out of sync with this once already. |
| `responders` | `>= 3.0` | Currently pulled in specifically "to hopefully work" with the dossier fork per the Gemfile's own comment — re-evaluate once dossier is gone; it may no longer be needed at all |

### What this roadmap deliberately does not cover

- **Whether or when to adopt Turbo, Propshaft, Solid Queue/Cache/Cable, or
  Kamal.** Each is called out above as available, none as required. Treat
  each as its own small decision when its hop arrives, not as part of the
  version bump itself.
- **A Capistrano → Kamal deploy migration.** Out of scope entirely; would be
  its own project with its own plan.
- **Any specific claim about Rails 8.2**, since it may not exist yet.
- **Scheduling.** This is a shape-of-the-work document, not a "hop N happens
  in month M" calendar. The hard lesson from 5.1→6.1 — ship each hop before
  starting the next, don't let two run in parallel — matters more than any
  specific pace.

---

<a name="principles"></a>
## Principles for the remaining hops

These are the hardest-won lessons from the 5.1→6.1 upgrade, stated as rules
rather than anecdotes:

1. **One Rails minor per branch.** The original 5.2 → 6.1 jump happened in a
   single commit *that also moved Ruby 2.7.4 → 3.2.10*, skipping Rails 6.0 and
   Ruby 3.0/3.1 entirely. That's why regressions couldn't be attributed to a
   cause — every failure had two candidate explanations.
2. **Ruby bumps get their own commit**, separate from Rails bumps, for the same
   reason. Not moot — see [Ruby version](#ruby-bump-decision) above: a Ruby
   bump past 3.2 is now planned as its own standalone hop, ahead of 7.0.
3. **Bump `config.load_defaults` last.** Enable each `new_framework_defaults_*`
   setting individually, verify, and only then bump the version — otherwise
   `load_defaults` turns them all on at once and you're back to unattributable
   failures. Read the settings out of the installed railties gemspec's
   `load_defaults` case statement, not the shipped template comments; the
   templates are stale and there won't be a template at all for a version you
   skipped.
4. **Cookie/CSRF/session wire-format settings can't be verified by a green test
   suite.** They only manifest across a real deploy against real existing
   sessions. On the 6.1 branch they were safe to enable wholesale because
   nothing was deployed from it yet. Now that 6.1 is in production that stops
   being true, and every hop's settings need a deploy-and-watch of their own.

---

## Landmines — do not undo these

Each of these looks like something to clean up and is not.

**`Capfile`'s `lock` string drifted from the `Gemfile`'s own constraint —
found and fixed the day before the 6.1 cutover.** `Capfile` had `lock
"3.9.0"` (an exact-version match — confirmed by reading Capistrano's own
`VersionValidator`/`lock` source: it raises on *either* direction of
mismatch, not just a floor check), while `Gemfile` has `gem 'capistrano', '~>
3.9'`, which had resolved to 3.20.0 (`Gemfile.lock`, since commit `f651829`).
Every real `cap` command (not `cap --version`, which skips loading the
Capfile) aborted with `Capfile locked at 3.9.0, but 3.20.0 is loaded`. Fixed
by changing the lock to `lock "~> 3.9"`, matching the Gemfile's own loose
constraint rather than forcing capistrano back down to exactly 3.9.0 (which
would have introduced a new, unvalidated variable into the deploy tool itself
immediately before using it). **Re-check this any time the resolved
capistrano version moves** — the `Capfile` lock does not auto-track the
`Gemfile` constraint, so they can silently diverge again.

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
which was still on the pre-upgrade Rails at the time.

**The generalisable lesson:** options that Rails silently ignores are invisible
until a default flips. `grep -rn "form_with" app/views/` before each remaining
hop — there are only two uses today (`departments/_form` correctly passes
`local: true`), so this is cheap insurance.

The regression guard lives in `test/controllers/admin_controller_test.rb`
(`assert_select "form#estimate-form[data-remote=?]"`), not only in the system
test, because it is a property of rendered markup and can therefore be checked
deterministically. Confirmed it fails without the fix. The system test (now
shipped on `upgrade_app`, `test/system/delete_link_test.rb` for the related
UJS mechanism) covers what markup cannot: that the handler is bound when the
page is reached through a Turbolinks link.

<a name="redirect-rewrite"></a>
**RedirectToReferrer needs rewriting — come back to this.** Not done during
the 6.1 upgrade on purpose: it is app behaviour change, and the 6.1 diff
stayed a pure upgrade. Now scheduled as a 7.0 prerequisite (see
[above](#before-70)), since Rails 7.0's `raise_on_open_redirects` default
turns this from a latent note into an active risk.

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
  was found broken; see above.
- `delete_link_test.rb` — covers the rails-ujs mechanism behind every
  `method: :delete` link in the app. Went in before the cutover because UJS
  breakage is a failure mode this upgrade already produced once (see
  `estimate_pay.html.erb` above).

The two GET-only files are stable; the form test inherits the dropped-
interaction problem above. Prefer GET-only targets when adding more, and check
`grep -rln "turbolinks:load" app/assets/javascripts/` before picking a page.

---

## Open items

| Item | Forced by | Notes |
| --- | --- | --- |
| Merge `upgrade_app`/`master` back into `develop` | nothing — but blocks the 7.0 prerequisites above | `develop` is still pre-6.1; do this before opening a `7.0` branch |
| CI workflow | nothing — but everything in [Do these before 7.0](#before-70) depends on it | written and validated, **parked** on `ci-github-actions`; has never run on GitHub. `git checkout ci-github-actions -- .github/workflows/ci.yml` restores it. See [CI](#ci-undecided) for the decisions that gate switching it on. |
| Privating the GitHub repo | option 4 of the CI decision | see [Privating the GitHub repo](#privating-the-repo); planned, not yet done |
| `config/secrets.yml` → credentials or ENV | **Rails 7.2** | also a Capistrano linked file; do before 7.0 per prerequisites above |
| `app/models/user.rb:10-27` | nothing | 18 lines of debug notes pasted verbatim into the model, matching the May notes almost word for word. The diagnosis it records was wrong. Delete. |
| `rails-version-change` branch | nothing | 2024, Rails 5.2.8.1 / Ruby 2.6.10 — superseded, delete to avoid confusion about which path is current |
| `pg 1.6.3` PG::Coder noise | nothing | clears at 7.1, no action |
| Delete `app/views/payslips/show.html.erb` | nothing | Confirmed dead: every link passes `format: :pdf` and `process_employee_complete` redirects to the PDF, so the `format.html` branch is unreachable except by hand-editing a URL. Debug output, not a page. Worth removing, now that 6.1 has shipped — removing it means dropping `format.html` from `PayslipsController#show` too. |
| Ruby version past 3.2.10 | nothing yet — EOL pressure only | see [Ruby version](#ruby-bump-decision); timing decided (standalone hop, step 4 of [Plan from here](#plan-from-here)), target version (3.4.9 or newer) not finalized |
| Dossier removal | nothing | see [Dossier](#dossier); do before 7.0 per prerequisites above |
| `RedirectToReferrer` rewrite | effectively Rails 7.0 (`raise_on_open_redirects`) | see [above](#redirect-rewrite); do before 7.0 per prerequisites |

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
cherry-picked onto `develop` (commit `09cdac2`) so it travels with the code
rather than sitting on a branch that's a cleanup candidate.

Not forced by any Rails version. Worth doing before 7.x rather than after, since
every hop re-tests a fork nobody maintains.

### Debt with no deadline

Unmaintained or superseded, but nothing in the roadmap forces them. Listed so
nobody mistakes them for blockers: turbolinks 5.2.1 (→ Turbo), coffee-rails and
the 12 `.coffee` files, jquery-rails 4.3.5, bootstrap-sass 3.4.1.

---

<a name="post-upgrade-pass"></a>
## Post-upgrade pass, on `develop`

Found while validating 6.1 by hand (the full manual QA pass, formerly tracked
in `upgrade-6.1-validation.txt`, is complete: every area — employees, payslip
corrections, bonuses, charges, misc payments, work hours, overtime, loans,
work loans, all reports, holidays, standard charge notes, timesheets — checked
out OK except the two bugs below, both pre-existing). Neither bug below is
**caused by** 6.1 — neither mechanism depends on any 6.1 behaviour change.
They belong on `develop`, so the 6.1 diff stayed a pure upgrade. Worth a
30-second confirmation on `develop` before fixing, since that has not been
done.

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

### 4. Test coverage gaps found while reviewing the system suite

Ranked by what a controller test **structurally cannot see**, not by how
important the feature is. The system suite is selenium-driven and serial
(see `test/application_system_test_case.rb`), so every browser test costs real
wall-clock; anything a controller test can reach should stay a controller test.

**Capybara, because only a browser sees it:**

- **Vacations.** `wait_for_vacation_form` exists in
  `test/application_system_test_case.rb` with eight lines documenting an
  observed failure — "the server never receives POST /vacations at all" — but
  its only caller is `RedirectTest`, which uses the vacation form as a vehicle
  for testing redirects. Nothing tests the form itself. Two things are
  uncovered: the `vacations.coffee` AJAX that blanks `#days-summary` and
  refills it from `days_summary`, and the `overlap_alert.html.erb`
  interstitial — submit, get a page listing the overlapped work hours, confirm
  with `confirm_delete_work_hours`. That second one is a genuine multi-step
  flow with no non-browser equivalent. The expensive part, the synchronisation
  primitive, is already written.

- **Conditional `disabled` toggles**, three of them sharing one failure mode:
  `employees.coffee` (echelon `g` enables `input[data-wage]`), `users.coffee`
  (the new-person radio swaps `select#user_person_id` against the name
  inputs), and `work_hours.coffee` (the excused-absence checkbox enables the
  excuse inputs and zeroes hours when cleared). These matter because **disabled
  inputs do not submit**: a JS regression silently changes the params the
  server receives, and a controller test that builds its params hash by hand
  sees a perfectly valid request. Note `EmployeeFormTest` uses the `:personal`
  page specifically to avoid these animations, so the wage toggle is
  explicitly outside its scope.

Not worth a browser: `bonuses.coffee` (swaps a `%`/`FCFA` span) and
`tool_tips.coffee`. Cosmetic.

**Not Capybara — `test/integration/` is empty, and that is the bigger hole:**

- Controllers with zero tests: `misc_payments`, `payslip_corrections`,
  `raises`, `sessions`, `home`. The first two are the notable ones — items 1
  and 2 above are open bugs in exactly those controllers, with no test file to
  put the regression test in.
- Checklist items never confirmed by hand during the 6.1 validation pass:
  post a period, unpost a period, process by location, process a single
  employee, look back. All plain POSTs to `payslips#post_period`,
  `#unpost_period`, `#process_bro_employees` and friends — controller or
  integration tests, much cheaper and steadier than driving them through
  Chrome, and with no new 6.1-specific risk, so these were never a go-live
  blocker — just worth confirming/covering now.

### Also on the list

- Delete `app/views/payslips/show.html.erb` and the `format.html` branch of
  `PayslipsController#show` — see Open items.
- Rewrite `RedirectToReferrer` — see [above](#redirect-rewrite), which also
  unskips `RedirectTest#test_Does_not_use_expired_redirects`.
