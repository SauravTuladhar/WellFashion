const { test, expect } = require('@playwright/test');

test('visiting the admin dashboard with no session redirects to admin login', async ({ page }) => {
  await page.goto('/admin/dashboard.html', { waitUntil: 'networkidle' });
  await page.waitForTimeout(500);
  await expect(page).toHaveURL(/admin\/login\.html/);
});

test('admin login rejects a wrong password', async ({ page }) => {
  await page.goto('/admin/login.html', { waitUntil: 'networkidle' });
  await page.fill('#adminEmail', 'not-a-real-admin@example.com');
  await page.fill('#adminPassword', 'wrongpassword123');
  await page.click('#adminLoginForm button[type="submit"]');
  await page.waitForTimeout(1500);

  await expect(page).toHaveURL(/admin\/login\.html/);
  await expect(page.locator('#adminLoginAlert')).not.toBeEmpty();
});
