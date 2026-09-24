import { expect, type Locator, type Page } from '@playwright/test';
import type { MockScenario } from './fixtures';

/**
 * Flutter web draws to a canvas; the only stable DOM is the semantics tree.
 * `TestId` widgets expose `Semantics(identifier: …)`, which Flutter web
 * renders as the `flt-semantics-identifier` attribute. No XPath, no text.
 */
export class FlutterApp {
  constructor(readonly page: Page) {}

  /** Opens the app at a route (hash URL strategy) in a mock scenario. */
  async open(route = '/home', scenario?: MockScenario): Promise<void> {
    const query = scenario ? `?scenario=${encodeURIComponent(scenario)}` : '';
    await this.page.goto(`/${query}#${route}`);
    await this.enableSemantics();
  }

  /** Turns on Flutter's semantics tree (off by default on web). */
  async enableSemantics(): Promise<void> {
    const placeholder = this.page.locator('flt-semantics-placeholder');
    await placeholder.waitFor({ state: 'attached', timeout: 60_000 });
    await placeholder.dispatchEvent('click');
    await this.page
      .locator('[flt-semantics-identifier]')
      .first()
      .waitFor({ state: 'attached', timeout: 30_000 });
  }

  byId(id: string): Locator {
    return this.page.locator(`[flt-semantics-identifier="${id}"]`);
  }

  /**
   * Scrolls the Flutter view until [id] is in the semantics tree. Lazily
   * built lists only expose on-screen items, exactly as on mobile, so this
   * mirrors `BaseRobot.reveal` in the Flutter suite.
   */
  async reveal(id: string, maxScrolls = 15): Promise<Locator> {
    const viewport = this.page.viewportSize() ?? { width: 1280, height: 900 };
    await this.page.mouse.move(viewport.width / 2, viewport.height / 2);
    for (let i = 0; i < maxScrolls && (await this.byId(id).count()) === 0; i++) {
      await this.page.mouse.wheel(0, 400);
      await this.page.waitForTimeout(250);
    }
    return this.waitFor(id);
  }

  async waitFor(id: string): Promise<Locator> {
    const el = this.byId(id).first();
    await el.waitFor({ state: 'visible' });
    return el;
  }

  async tap(id: string): Promise<void> {
    await (await this.waitFor(id)).click();
  }

  /**
   * Taps [id] where the app is expected to IGNORE the tap (a disabled control).
   *
   * Flutter web gives a disabled control no pointer target of its own, so
   * Playwright's actionability check always sees the canvas "intercepting"
   * and never clicks. This sends a real pointer click at the element's
   * position without that check, and Flutter's own hit-testing decides. If
   * the control were wrongly enabled, the tap would take effect and the
   * caller's assertion would fail — unlike a synthetic event dispatched to
   * the semantics container, which carries no tap action at all.
   */
  async tapExpectingNoEffect(id: string): Promise<void> {
    await (await this.waitFor(id)).click({ force: true });
    await this.waitForFrames(1);
  }

  /** Taps [id] only if it appears within [ms]; returns whether it did. */
  async tapIfShown(id: string, ms = 2_000): Promise<boolean> {
    try {
      await this.byId(id).first().waitFor({ state: 'visible', timeout: ms });
    } catch {
      return false;
    }
    await this.tap(id);
    return true;
  }

  /**
   * Focuses a text field by id and types into it like a user.
   *
   * Flutter web creates the DOM <input> as soon as the field is clicked, but
   * only reads from it after the framework's focus round-trip completes.
   * Keystrokes sent before that land in the DOM and are then discarded (the
   * engine resets the input to the app's empty state). So: wait for focus
   * and a few rendered frames, type, and verify the text survived; retry the
   * whole interaction if Flutter reset it. Fails if it never takes.
   */
  async fill(id: string, text: string): Promise<void> {
    const field = await this.waitFor(id);
    const input = field.locator('input, textarea').first();
    for (let attempt = 1; attempt <= 3; attempt++) {
      await field.click();
      await expect(input).toBeFocused();
      await this.waitForFrames(3);
      await this.page.keyboard.press('ControlOrMeta+A');
      await this.page.keyboard.type(text, { delay: 25 });
      await this.waitForFrames(5);
      if ((await input.inputValue().catch(() => '')) === text) return;
    }
    await expect(input, `Flutter did not accept text for "${id}"`).toHaveValue(text);
  }

  /** Resolves after [count] browser animation frames (Flutter renders per frame). */
  private async waitForFrames(count: number): Promise<void> {
    await this.page.evaluate(
      (n) =>
        new Promise<void>((resolve) => {
          const step = (left: number) => (left <= 0 ? resolve() : requestAnimationFrame(() => step(left - 1)));
          step(n);
        }),
      count,
    );
  }

  async expectShown(id: string): Promise<void> {
    await expect(this.byId(id).first()).toBeVisible();
  }

  async expectNotShown(id: string): Promise<void> {
    await expect(this.byId(id)).toHaveCount(0);
  }

  /** Asserts the router location (hash URL strategy), e.g. `/profile`. */
  async expectLocation(route: string): Promise<void> {
    const escaped = route.replace(/[.*+?^${}()|[\]\\/]/g, '\\$&');
    await expect(this.page).toHaveURL(new RegExp(`#${escaped}$`));
  }

  /**
   * Pops the current route with the app bar's automatic back button.
   * go_router `push` does not add browser history entries, so browser back
   * is not equivalent. The button is framework-generated (Material "Back"
   * tooltip), not app copy, so this is the one role/name locator we use.
   */
  async back(): Promise<void> {
    // Let any running route transition finish first: while it runs, Flutter
    // keeps re-creating the button's semantics node, so a normal click never
    // sees a stable element. Then dispatch the tap to the settled node.
    await this.waitForFrames(30);
    const button = this.page.getByRole('button', { name: 'Back', exact: true }).first();
    await button.waitFor({ state: 'visible' });
    await button.dispatchEvent('click');
    await this.waitForFrames(30);
  }
}
