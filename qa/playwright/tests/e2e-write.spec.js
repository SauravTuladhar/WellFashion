// WRITES REAL DATA TO PRODUCTION SUPABASE: a real auth.users row, and (if it
// gets that far) a real order. Never runs by default -- only with
// QA_ALLOW_WRITES=1 (see package.json's "test:write" script), and only
// after the user has explicitly agreed to it in the current conversation.
// See README.md before running this.
const { test, expect } = require('@playwright/test');

test.skip(
  process.env.QA_ALLOW_WRITES !== '1',
  'Set QA_ALLOW_WRITES=1 to run tests that write real data to production ' +
  '(npm run test:write). Only run this after the user has explicitly agreed ' +
  'in the current conversation -- see qa/playwright/README.md.'
);

const TEST_EMAIL = `wellfashion.qa.${Date.now()}@gmail.com`;
const TEST_PASSWORD = 'QaTest1234!';
const TEST_NAME = 'WellFashion QA Tester';

test.describe.configure({ mode: 'serial' });

let signupGaveSession = false;

test('signup creates a real Supabase Auth account', async ({ page }) => {
  await page.goto('/account/signup.html', { waitUntil: 'networkidle' });
  await page.fill('#signupName', TEST_NAME);
  await page.fill('#signupEmail', TEST_EMAIL);
  await page.fill('#signupPassword', TEST_PASSWORD);
  await page.fill('#signupConfirm', TEST_PASSWORD);
  await page.click('#signupForm button[type="submit"]');
  await page.waitForTimeout(2000);

  const alertText = (await page.locator('#signupAlert').textContent()) || '';
  // eslint-disable-next-line no-console
  console.log(
    `[e2e-write] created test account ${TEST_EMAIL} -- cleanup SQL: ` +
    `delete from auth.users where email = '${TEST_EMAIL}';`
  );

  if (/confirm/i.test(alertText)) {
    test.skip(
      true,
      `Supabase "Confirm email" is enabled for this project, so ${TEST_EMAIL} ` +
      'cannot log in without clicking a confirmation link. This is a project ' +
      'setting, not a code defect -- see qa/playwright/README.md. Remaining ' +
      'tests in this file are blocked until it is disabled or the account is ' +
      'confirmed manually.'
    );
  }

  signupGaveSession = page.url().includes('account.html') || /welcome/i.test(alertText);
  expect(signupGaveSession, `unexpected signup outcome: "${alertText}"`).toBe(true);
});

test('login, place a real order, and see it in My Orders', async ({ page }) => {
  test.skip(!signupGaveSession, 'signup did not produce an immediate session');

  await page.goto('/account/login.html', { waitUntil: 'networkidle' });
  await page.fill('#loginEmail', TEST_EMAIL);
  await page.fill('#loginPassword', TEST_PASSWORD);
  await page.click('#loginForm button[type="submit"]');
  await page.waitForTimeout(1500);
  await expect(page).toHaveURL(/account\.html/);

  await page.evaluate(() => {
    localStorage.setItem('wellfashion_cart', JSON.stringify([{ id: 'wf-casual-cotton-top', qty: 2 }]));
  });
  await page.goto('/shop/checkout.html', { waitUntil: 'networkidle' });
  await page.waitForTimeout(600);
  await expect(page.locator('#checkoutView')).toBeVisible();

  await page.fill('#ckNameInput', TEST_NAME);
  await page.fill('#ckPhoneInput', '9800000000');
  await page.fill('#ckAddressInput', 'QA Test Address, Kathmandu');
  await page.click('#checkoutForm button[type="submit"]');
  await page.waitForTimeout(2500);

  await expect(page.locator('#confirmationView')).toBeVisible();
  const confirmText = (await page.locator('#confirmationText').textContent()) || '';
  const match = confirmText.match(/#(WF-[A-Z0-9]+)/);
  expect(match, `no order code in confirmation text: "${confirmText}"`).toBeTruthy();
  const orderCode = match[1];
  // eslint-disable-next-line no-console
  console.log(`[e2e-write] placed real order ${orderCode} for ${TEST_EMAIL}`);

  const cartAfter = await page.evaluate(() => JSON.parse(localStorage.getItem('wellfashion_cart') || '[]'));
  expect(cartAfter).toEqual([]);

  await page.goto('/account/orders.html', { waitUntil: 'networkidle' });
  await page.waitForTimeout(1200);
  await expect(page.locator('#ordersList')).toContainText(orderCode);
});

test('admin login denies this (non-admin) account', async ({ page }) => {
  test.skip(!signupGaveSession, 'signup did not produce an immediate session');

  await page.goto('/admin/login.html', { waitUntil: 'networkidle' });
  await page.fill('#adminEmail', TEST_EMAIL);
  await page.fill('#adminPassword', TEST_PASSWORD);
  await page.click('#adminLoginForm button[type="submit"]');
  await page.waitForTimeout(1500);

  await expect(page).toHaveURL(/admin\/login\.html/);
  await expect(page.locator('#adminLoginAlert')).toContainText(/admin access/i);
});
