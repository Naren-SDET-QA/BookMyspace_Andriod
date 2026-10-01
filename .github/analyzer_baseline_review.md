# Analyzer baseline review

This review accompanies `.github/analyzer_baseline_flutter_3.44.0.json`.

## Toolchain

- Flutter: `3.44.0`
- Dart: `3.12.0`
- Flutter framework revision: `559ffa3f75e7402d65a8def9c28389a9b2e6fe42`
- Baseline source commit: `3346556b390fde01cc028af880c8f6bf9b088962`

## Comparison

The analyzer was run against clean temporary copies of:

- the previous baseline source: `510922d400ee19fe0d6ee66b59d7ebaa352623b4`
- the parent commit: `07beb9371372cc0c1674a963c4c5832f190724a1`
- the current commit: `3346556b390fde01cc028af880c8f6bf9b088962`

The parent and current commit produced identical analyzer findings. The current
commit changes only SQL migrations, so it introduces no Dart diagnostics.

The previous baseline allowed 26 warnings and 446 infos. The clean current tree
contains 54 warnings and 610 infos. The validator therefore reported 393
diagnostic occurrences outside the previous baseline; these are baseline drift,
not a regression from the booking migration commit.

## Review classification

| Classification | Result |
| --- | ---: |
| New diagnostics introduced by `3346556b` | 0 |
| Toolchain/configuration mismatch | 0 |
| Current reviewed warnings | 54 |
| Current reviewed infos | 610 |
| Current baseline records | 343 |

The baseline records the clean current tree so the existing validator continues
to enforce the same controlled policy without changing analyzer rules.

## Correctness-sensitive follow-up

The following pre-existing diagnostics remain visible in the analyzer output and
were not changed in this CI-only remediation:

- `use_build_context_synchronously` in production and integration-test code
- `unawaited_futures` in production and integration-test code
- `dead_code`, `dead_null_aware_expression`, and unnecessary-null diagnostics

These require a separate Flutter source review. They are explicitly documented
here and are not claimed to be fixed by the baseline update. No Flutter source,
booking behavior, authentication, payment behavior, or database object was
modified by this remediation.
