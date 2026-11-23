const { test, expect } = require('@playwright/test');

test('home page renders product cards from the Supabase catalog', async ({ page }) => {
  await page.goto('/index.html', { waitUntil: 'networkidle' });
  await page.waitForTimeout(800); // loadCatalog() resolves asynchronously
  await expect(page.locator('.product-card')).not.toHaveCount(0);
});

test('search autosuggest returns a match', async ({ page }) => {
  await page.goto('/index.html', { waitUntil: 'networkidle' });
  await page.waitForTimeout(800);
  await page.fill('#searchInput', 'kurtha');
  await page.waitForTimeout(400);
  await expect(page.locator('#searchSuggest li')).not.toHaveCount(0);
});

test('add to cart updates the header cart badge', async ({ page }) => {
  await page.goto('/shop/category.html?cat=kurtha', { waitUntil: 'networkidle' });
  await page.waitForTimeout(800);
  const firstCard = page.locator('.product-card').first();
  await firstCard.locator('.btn-add').click();
  await expect(page.locator('#cartBadge')).toHaveText('1');
});

test('wishlist toggle updates the header wishlist badge', async ({ page }) => {
  await page.goto('/shop/category.html?cat=kurtha', { waitUntil: 'networkidle' });
  await page.waitForTimeout(800);
  const firstCard = page.locator('.product-card').first();
  await firstCard.locator('.wish-toggle').click();
  await expect(page.locator('#wishlistBadge')).toHaveText('1');
});
