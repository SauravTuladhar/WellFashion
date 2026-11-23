const { test, devices } = require('@playwright/test');

const PAGES = [
  'index.html',
  'shop/category.html?cat=kurtha',
  'shop/cart.html',
  'shop/checkout.html',
  'account/login.html',
  'account/orders.html',
  'info/careers.html',
  'info/download-app.html',
];

for (const p of PAGES) {
  const name = p.split('?')[0].replace(/\//g, '_').replace('.html', '');

  test(`desktop ${p}`, async ({ browser }) => {
    const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 } });
    const page = await ctx.newPage();
    await page.goto('/' + p);
    await page.waitForTimeout(600);
    await page.screenshot({ path: `shots/desktop_${name}.png`, fullPage: true });
    await ctx.close();
  });

  test(`mobile ${p}`, async ({ browser }) => {
    const ctx = await browser.newContext({ ...devices['iPhone 13'] });
    const page = await ctx.newPage();
    await page.goto('/' + p);
    await page.waitForTimeout(600);
    await page.screenshot({ path: `shots/mobile_${name}.png`, fullPage: true });
    await ctx.close();
  });
}

test('desktop open megamenu + cart drawer on index', async ({ browser }) => {
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 } });
  const page = await ctx.newPage();
  await page.goto('/index.html');
  await page.click('#allCatsBtn');
  await page.waitForTimeout(400);
  await page.screenshot({ path: 'shots/desktop_index_megamenu.png' });
  await page.click('#allCatsBtn');
  await page.click('#cartBtn');
  await page.waitForTimeout(400);
  await page.screenshot({ path: 'shots/desktop_index_cartdrawer.png' });
  await ctx.close();
});
