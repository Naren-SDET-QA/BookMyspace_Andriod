# Analyzer baseline review

This review accompanies `.github/analyzer_baseline_flutter_3.44.0.json`.

## Toolchain

- Flutter: `3.44.0`
- Dart: `3.12.0`
- Flutter framework revision: `559ffa3f75e7402d65a8def9c28389a9b2e6fe42`
- Baseline source commit: `0dd908de35b278c9ff58d840ea3e35f66eecd183`

## Historical baseline review

The analyzer was run against clean temporary copies of:

- the previous baseline source: `510922d400ee19fe0d6ee66b59d7ebaa352623b4`
- the parent commit: `07beb9371372cc0c1674a963c4c5832f190724a1`
- the current commit: `3346556b390fde01cc028af880c8f6bf9b088962`

The parent and current commit produced identical analyzer findings. The current
commit changes only SQL migrations, so it introduces no Dart diagnostics.

The prior review covered a SQL-only migration commit and found zero new Dart
diagnostics. Its analyzer baseline was based on an earlier tree and later fell
behind the main branch.

## Phase 1 baseline reconciliation

Both runs used the CI-pinned Flutter 3.44.0 / Dart 3.12.0 toolchain and the same
analyzer validator:

- Main baseline commit `89c9fc629b612684251b20ecc6a999000faa378f`, run
  `37103543185`: **110** diagnostic occurrences beyond the old baseline.
- Marketplace branch commit `0dd908de35b278c9ff58d840ea3e35f66eecd183`, run
  `39092759233`: **95** occurrences beyond that baseline.

The diagnostic fingerprints `(severity, code, file, message)` were compared
directly. All 95 marketplace-branch occurrences were already present in the
main-branch run; **zero branch-only diagnostics** were found. Fifteen main-run
diagnostics no longer occur on the marketplace branch. This is evidence-based
baseline drift reconciliation, not an expansion to conceal new branch issues.
The reviewed baseline now records the exact pinned-toolchain analyzer output
for the marketplace source commit so the validator can continue rejecting any
new diagnostics in subsequent changes. Analyzer rules and CI gates are
unchanged.

## Review classification

| Classification | Result |
| --- | ---: |
| Branch-only diagnostics vs main | 0 |
| Marketplace diagnostics absent from main | 15 |
| Current reviewed warnings | 80 |
| Current reviewed infos | 679 |
| Current baseline records | 396 |

The baseline does not imply a clean whole-repository analyzer. The existing
diagnostics are still visible and require ongoing cleanup; the new baseline
only prevents those reviewed inherited findings from blocking unrelated work.

## Correctness-sensitive follow-up

The following pre-existing diagnostics remain visible in the analyzer output and
were not changed in this CI-only remediation:

- `use_build_context_synchronously` in production and integration-test code
- `unawaited_futures` in production and integration-test code
- `dead_code`, `dead_null_aware_expression`, and unnecessary-null diagnostics

These require a separate Flutter source review. They are explicitly documented
here and are not claimed to be fixed by the baseline update. The marketplace
branch fixes its own analyzer findings in the router, Home screen and
registration tests; no analyzer rule is suppressed.
