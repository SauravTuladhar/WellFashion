// WellFashion QA config. The same spec files run against a local dev server or
// the live production site -- only QA_BASE_URL changes (see package.json's
// "test" vs "test:live" scripts). Every test must use relative paths
// (page.goto('/index.html'), not a hardcoded host) so that holds.
const { defineConfig, devices } = require('@playwright/test');

module.exports = defineConfig({
  testDir: './tests',
  fullyParallel: true,
  reporter: [['list'], ['html', { open: 'never' }]],
  use: {
    baseURL: process.env.QA_BASE_URL || 'http://localhost:8787',
    trace: 'retain-on-failure',
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
});
