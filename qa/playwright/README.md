# WellFashion QA (Playwright)

A real, checked-in [`@playwright/test`](https://playwright.dev/) project for regression-testing WellFashion. This lives entirely under `qa/playwright/` and is intentionally separate from the site root, which has no `package.json` or build step by design (plain static HTML/CSS/JS — see the repo's `CLAUDE.md`). Nothing here affects how the site itself is built, served, or deployed.

## Setup

```bash
cd qa/playwright
npm install
npm run install-browsers   # downloads the Chromium build Playwright drives
```

## Running locally

Start the site's own dev server from the repo root in one terminal:

```bash
python3 -m http.server 8787
```

Then, from `qa/playwright/`:

```bash
npm test             # headless, against http://localhost:8787
npm run test:headed  # same, with a visible browser window
```

## Running against production

```bash
npm run test:live    # same spec files, against https://sauravtuladhar.github.io/wellfashion
```

Every spec file uses relative `page.goto('/path.html')` calls and reads the target host from `playwright.config.js`'s `baseURL` (driven by the `QA_BASE_URL` env var), so the exact same tests run against either target — nothing in the test code needs to change.

This is safe to run against the live site at any time: `smoke.spec.js`, `catalog.spec.js`, `checkout.spec.js`, `admin.spec.js`, and `branding.spec.js` only read — they never sign up an account, log in as a real user, or place an order.

## `tests/e2e-write.spec.js` — writes real production data

This one file is different: it signs up a real Supabase Auth account, places a real order, and checks it shows up in order history and that the account is correctly denied admin access. It is skipped by default — it only runs via:

```bash
npm run test:write
```

which sets `QA_ALLOW_WRITES=1`. **Never run this against production without the user explicitly agreeing to it in the current conversation first.** It uses a clearly-labeled, timestamped test identity (`wellfashion.qa.<timestamp>@gmail.com`) and always logs the exact cleanup SQL for the account it creates, e.g.:

```sql
delete from auth.users where email = 'wellfashion.qa.1760000000000@gmail.com';
```

Note: Supabase's "Confirm email" project setting, if enabled, blocks this account from getting an immediate session after signup. If that's the case, the test detects the "confirm your email" message and skips the remaining assertions with a clear explanation rather than failing or trying to work around it — that's a project/dashboard setting, not a code defect.

## Viewing results

```bash
npm run report   # opens the last HTML report (playwright-report/)
```

Generated output (`node_modules/`, `test-results/`, `playwright-report/`, `blob-report/`) is gitignored — see the root `.gitignore`.

## Continuous integration

`.github/workflows/qa.yml` runs this suite on every push to `main` and on every pull request: it starts `python3 -m http.server 8787` from the repo root, then runs `npm test` from `qa/playwright/` against it — the same `test` script you'd run locally, against the live Supabase project (there's no mock backend). `e2e-write.spec.js` stays skipped automatically since the workflow never sets `QA_ALLOW_WRITES=1`. On failure, the HTML report is uploaded as a build artifact for 14 days.
