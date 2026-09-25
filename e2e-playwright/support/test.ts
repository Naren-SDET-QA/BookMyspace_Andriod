import { test as base } from '@playwright/test';
import { FlutterApp } from './flutter';

/** `test` with an `app` fixture bound to the page. */
export const test = base.extend<{ app: FlutterApp }>({
  app: async ({ page }, use) => {
    await use(new FlutterApp(page));
  },
});

export { expect } from '@playwright/test';
