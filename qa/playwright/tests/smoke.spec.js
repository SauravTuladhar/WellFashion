// Catches a stale CSP inline-script hash or a JS crash: either shows up as a
// console error or a pageerror, even though the page still returns HTTP 200
// and looks fine in a glance. This is the single most valuable check here.
const { test, expect } = require('@playwright/test');

const PAGES = [
  'index.html',
  'shop/category.html',
  'shop/product.html',
  'shop/cart.html',
  'shop/wishlist.html',
  'shop/checkout.html',
  'account/login.html',
  'account/signup.html',
  'account/account.html',
  'account/orders.html',
  'account/track-order.html',
  'info/about.html',
  'info/blog.html',
  'info/careers.html',
  'info/contact.html',
  'info/download-app.html',
  'info/help-center.html',
  'info/how-to-buy.html',
  'info/privacy.html',
  'info/returns.html',
  'info/seller.html',
  'info/terms.html',
  'admin/login.html',
  'admin/dashboard.html',
  '404.html',
];

for (const path of PAGES) {
  test(`${path} loads with no console/page errors`, async ({ page }) => {
    const errors = [];
    page.on('console', (msg) => {
      if (msg.type() === 'error') errors.push(msg.text());
    });
    page.on('pageerror', (err) => errors.push(`pageerror: ${err.message}`));

    await page.goto(`/${path}`, { waitUntil: 'networkidle' });
    await page.waitForTimeout(400); // let async loadCatalog()/auth listeners settle

    expect(errors, `console/page errors on ${path}:\n${errors.join('\n')}`).toEqual([]);
  });
}
