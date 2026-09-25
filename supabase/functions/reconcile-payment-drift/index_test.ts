// Phase 9XG focused tests for the pure, side-effect-free helpers exported
// from index.ts. These do not exercise Deno.serve, Supabase, or Razorpay
// -- that would require the full runtime this project already avoids
// unit-testing directly (see razorpay-webhook/helpers_test.ts for the
// same pattern: test the extractable pure logic, not the handler).
import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts';
import { mergeReconciliationMetadata, resolveDryRun } from './index.ts';

Deno.test('resolveDryRun defaults to true (dry-run) when body is empty', () => {
  assertEquals(resolveDryRun({}), true);
});

Deno.test('resolveDryRun defaults to true when dry_run is absent', () => {
  assertEquals(resolveDryRun({ other_field: 1 }), true);
});

Deno.test('resolveDryRun returns false only for explicit {dry_run:false}', () => {
  assertEquals(resolveDryRun({ dry_run: false }), false);
});

Deno.test('resolveDryRun ignores a truthy-but-not-boolean dry_run value (fail-closed to dry-run)', () => {
  assertEquals(resolveDryRun({ dry_run: 'false' }), true);
});

Deno.test('mergeReconciliationMetadata preserves unrelated existing keys (9XF MUST-FIX #1)', () => {
  const existing = { unrelated_key: 'must-survive', another: 42 };
  const result = mergeReconciliationMetadata(existing, { reconciliation_note: 'x', checked_at: 'now' });
  assertEquals(result.unrelated_key, 'must-survive');
  assertEquals(result.another, 42);
  assertEquals(result.reconciliation_note, 'x');
});

Deno.test('mergeReconciliationMetadata handles null existing metadata safely', () => {
  const result = mergeReconciliationMetadata(null, { reconciliation_note: 'x' });
  assertEquals(result.reconciliation_note, 'x');
});

Deno.test('mergeReconciliationMetadata handles non-object existing metadata safely (never throws)', () => {
  const result = mergeReconciliationMetadata('not-an-object', { reconciliation_note: 'x' });
  assertEquals(result.reconciliation_note, 'x');
});

Deno.test('mergeReconciliationMetadata patch overwrites only its own keys, not siblings', () => {
  const existing = { reconciliation_note: 'old', unrelated: 'keep' };
  const result = mergeReconciliationMetadata(existing, { reconciliation_note: 'new' });
  assertEquals(result.reconciliation_note, 'new');
  assertEquals(result.unrelated, 'keep');
});
