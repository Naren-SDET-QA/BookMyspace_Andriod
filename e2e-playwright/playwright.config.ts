import { defineConfig, devices } from '@playwright/test';
import { liveProblem } from './support/live';

/**
 * E2E_MODE=mock (default): serves the deterministic mock web build
 *   (`npm run build:web:mock`) locally. No Supabase, PR-safe.
 * E2E_MODE=live: targets an already-running DEV web build at
 *   E2E_WEB_BASE_URL. Credentials come only from environment variables.
 *   DEV only: any other Supabase project is refused (support/live.ts).
 *   Runs only tests/live; trace, video, screenshots and the HTML report
 *   are off so no credential can land in an artifact.
 */
const mode = process.env.E2E_MODE ?? 'mock';
const port = Number(process.env.E2E_WEB_PORT ?? 8787);
const mockBaseURL = `http://127.0.0.1:${port}`;
const baseURL = mode === 'live' ? process.env.E2E_WEB_BASE_URL : mockBaseURL;

if (mode === 'live' && !baseURL) {
  throw new Error('E2E_MODE=live requires E2E_WEB_BASE_URL (a DEV deployment).');
}
const live = mode === 'live';
const liveRefusal = live ? liveProblem(process.env) : null;
if (liveRefusal) throw new Error(`E2E_MODE=live refused: ${liveRefusal}`);

export default defineConfig({
  testDir: './tests',
  // Mock mode never runs live specs; live mode runs only them.
  testIgnore: live ? undefined : ['**/live/**'],
  testMatch: live ? ['live/**/*.spec.ts'] : undefined,
  timeout: 90_000,
  expect: { timeout: 20_000 },
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  // No automatic retries: a failure is reported as a failure.
  retries: 0,
  workers: process.env.CI ? 2 : undefined,
  reporter: live
    ? [['list'], ['junit', { outputFile: 'reports/junit/web-e2e-live.xml' }]]
    : [
        ['list'],
        ['html', { outputFolder: 'reports/html', open: 'never' }],
        ['junit', { outputFile: 'reports/junit/web-e2e.xml' }],
      ],
  outputDir: 'test-results',
  use: {
    baseURL,
    trace: live ? 'off' : 'retain-on-failure',
    screenshot: live ? 'off' : 'only-on-failure',
    video: live ? 'off' : 'retain-on-failure',
    viewport: { width: 1280, height: 900 },
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
  webServer:
    mode === 'mock'
      ? {
          command: `node support/serve.mjs ../build/e2e_web_mock ${port}`,
          url: mockBaseURL,
          reuseExistingServer: !process.env.CI,
          timeout: 60_000,
        }
      : undefined,
});
