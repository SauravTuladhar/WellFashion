const { test, expect } = require('@playwright/test');

test('checkout shows a login gate when logged out with items in cart', async ({ page }) => {
  // Each Playwright test gets a fresh, isolated browser context/localStorage,
  // so there is no session and no leftover cart here by default.
  await page.goto('/shop/checkout.html', { waitUntil: 'networkidle' });
  await page.evaluate(() => {
    localStorage.setItem('wellfashion_cart', JSON.stringify([{ id: 'wf-cotton-printed-kurtha', qty: 1 }]));
  });
  await page.reload({ waitUntil: 'networkidle' });
  await page.waitForTimeout(500);

  await expect(page.locator('#loginGate')).toBeVisible();
  await expect(page.locator('#checkoutView')).toBeHidden();
  await expect(page.locator('#emptyCartNotice')).toBeHidden();
});
