const { test, expect } = require('@playwright/test');

test('no "Daraz" or "SilvEra" branding on the home or about page', async ({ page }) => {
  await page.goto('/index.html', { waitUntil: 'networkidle' });
  await expect(page.locator('body')).not.toContainText(/daraz/i);
  await expect(page.locator('body')).not.toContainText(/silvera/i);

  await page.goto('/info/about.html', { waitUntil: 'networkidle' });
  await expect(page.locator('body')).not.toContainText(/daraz/i);
  await expect(page.locator('body')).not.toContainText(/silvera/i);
});

test('robots.txt disallows the admin area', async ({ request, baseURL }) => {
  const res = await request.get(`${baseURL}/robots.txt`);
  const body = await res.text();
  expect(body).toContain('Disallow: /admin/');
});

test('sitemap.xml excludes admin pages', async ({ request, baseURL }) => {
  const res = await request.get(`${baseURL}/sitemap.xml`);
  const body = await res.text();
  expect(body).not.toContain('/admin/');
});
