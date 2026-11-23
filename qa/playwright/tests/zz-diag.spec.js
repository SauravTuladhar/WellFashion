const { test } = require('@playwright/test');
test('diag2', async ({ page }) => {
  page.on('response', res => { if (res.status() >= 400) console.log('BAD STATUS', res.status(), res.url()); });
  await page.goto('index.html', { waitUntil: 'networkidle' });
  console.log('FINAL URL:', page.url());
  await page.waitForTimeout(500);
});
