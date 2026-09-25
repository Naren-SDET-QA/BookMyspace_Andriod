// Phase 9XG focused tests for reconcile-refunds' pure dry-run resolution
// helper. This is the single most important behavioral contract in this
// change: the live cron job posts an empty body, so an absent dry_run
// field MUST resolve to write mode (false), never dry-run (true) --
// getting this backwards would silently disable all real refund
// reconciliation while still returning HTTP 200 (see Phase 9XF finding).
import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts';
import { resolveDryRun } from './index.ts';

Deno.test('resolveDryRun returns false (write mode) for an empty body, matching the existing cron job', () => {
  assertEquals(resolveDryRun({}), false);
});

Deno.test('resolveDryRun returns false when dry_run is absent entirely', () => {
  assertEquals(resolveDryRun({ some_other_field: 1 }), false);
});

Deno.test('resolveDryRun returns true only for explicit {dry_run:true}', () => {
  assertEquals(resolveDryRun({ dry_run: true }), true);
});

Deno.test('resolveDryRun ignores a truthy-but-not-boolean dry_run value (fail-closed to write, matching existing behavior)', () => {
  assertEquals(resolveDryRun({ dry_run: 'true' }), false);
});

Deno.test('resolveDryRun treats explicit {dry_run:false} as write mode (no accidental flip)', () => {
  assertEquals(resolveDryRun({ dry_run: false }), false);
});
