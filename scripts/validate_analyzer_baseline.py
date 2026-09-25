#!/usr/bin/env python3
"""Fail when Flutter analyzer reports diagnostics absent from the reviewed baseline.

The baseline is intentionally read-only here. To change it, update the checked-in
baseline in a separately reviewed change; this validator never writes it.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
BASELINE_PATH = ROOT / ".github" / "analyzer_baseline_flutter_3.44.0.json"
EXPECTED_FLUTTER_VERSION = "3.44.0"
EXPECTED_DART_VERSION = "3.12.0"
DIAGNOSTIC_PREFIX = re.compile(r"^\s*(info|warning|error)\s+•")
LOCATION_SUFFIX = re.compile(r"^(.*):(\d+):(\d+)$")


def run(command: list[str], *, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        cwd=cwd,
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        errors="replace",
    )


def parse_diagnostics(output: str) -> tuple[list[dict[str, Any]], list[str]]:
    diagnostics: list[dict[str, Any]] = []
    malformed: list[str] = []

    for output_line, line in enumerate(output.splitlines(), start=1):
        if not DIAGNOSTIC_PREFIX.match(line):
            continue

        parts = [part.strip() for part in line.strip().split(" • ")]
        if len(parts) < 4 or parts[0] not in {"info", "warning", "error"}:
            malformed.append(f"output line {output_line}: {line}")
            continue

        location_match = LOCATION_SUFFIX.fullmatch(parts[-2])
        if location_match is None:
            malformed.append(f"output line {output_line}: {line}")
            continue

        file_path, line_number, column_number = location_match.groups()
        path = Path(file_path)
        if path.is_absolute():
            try:
                file_path = path.resolve().relative_to(ROOT).as_posix()
            except ValueError:
                malformed.append(f"diagnostic is outside the repository: {line}")
                continue
        else:
            file_path = path.as_posix().removeprefix("./")

        diagnostics.append(
            {
                "severity": parts[0],
                "message": " • ".join(parts[1:-2]),
                "file": file_path,
                "line": int(line_number),
                "column": int(column_number),
                "code": parts[-1],
            }
        )

    return diagnostics, malformed


def fingerprint(diagnostic: dict[str, Any]) -> tuple[str, str, str, str]:
    # Line/column are retained for reports but excluded from identity so harmless
    # edits above an existing finding do not make it appear to be a new lint.
    return (
        diagnostic["severity"],
        diagnostic["code"],
        diagnostic["file"],
        diagnostic["message"],
    )


def load_baseline() -> tuple[dict[str, Any], Counter[tuple[str, str, str, str]]]:
    try:
        baseline = json.loads(BASELINE_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError(f"Cannot read analyzer baseline {BASELINE_PATH}: {error}") from error

    if baseline.get("schema_version") != 1:
        raise ValueError("Unsupported analyzer baseline schema_version")
    if baseline.get("flutter_version") != EXPECTED_FLUTTER_VERSION:
        raise ValueError("Baseline is not pinned to Flutter 3.44.0")
    if baseline.get("dart_version") != EXPECTED_DART_VERSION:
        raise ValueError("Baseline is not pinned to Dart 3.12.0")

    counts: Counter[tuple[str, str, str, str]] = Counter()
    actual_severities: Counter[str] = Counter()
    for record in baseline.get("diagnostics", []):
        required = {"severity", "code", "file", "message", "count"}
        if not required.issubset(record):
            raise ValueError("Baseline contains a malformed diagnostic record")
        if record["severity"] not in {"info", "warning", "error"}:
            raise ValueError("Baseline contains an unknown diagnostic severity")
        if not isinstance(record["count"], int) or record["count"] < 1:
            raise ValueError("Baseline diagnostic counts must be positive integers")

        key = (
            record["severity"],
            record["code"],
            record["file"],
            record["message"],
        )
        counts[key] += record["count"]
        actual_severities[record["severity"]] += record["count"]

    expected_severities = baseline.get("diagnostic_counts", {})
    if any(actual_severities[level] != expected_severities.get(level, 0)
           for level in ("error", "warning", "info")):
        raise ValueError("Baseline records do not match diagnostic_counts metadata")

    return baseline, counts


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--flutter",
        default=os.environ.get("FLUTTER_BIN", "flutter"),
        help="Flutter executable (defaults to FLUTTER_BIN or flutter on PATH)",
    )
    args = parser.parse_args()

    try:
        baseline, allowed = load_baseline()
    except ValueError as error:
        print(f"Analyzer baseline validation failed: {error}", file=sys.stderr)
        return 2

    version_result = run([args.flutter, "--version", "--machine"], cwd=ROOT)
    if version_result.returncode != 0:
        print(version_result.stdout, file=sys.stderr, end="")
        print("Could not determine the Flutter/Dart toolchain.", file=sys.stderr)
        return 2

    try:
        toolchain = json.loads(version_result.stdout)
    except json.JSONDecodeError as error:
        print(f"Flutter did not return machine-readable version data: {error}", file=sys.stderr)
        return 2

    actual_flutter = toolchain.get("frameworkVersion") or toolchain.get("flutterVersion")
    actual_dart = toolchain.get("dartSdkVersion")
    expected_revision = baseline.get("flutter_framework_revision")
    actual_revision = toolchain.get("frameworkRevision")
    if (
        actual_flutter != EXPECTED_FLUTTER_VERSION
        or actual_dart != EXPECTED_DART_VERSION
        or actual_revision != expected_revision
    ):
        print(
            "Analyzer baseline requires Flutter 3.44.0 / Dart 3.12.0 "
            f"(framework {expected_revision}); got Flutter {actual_flutter} / "
            f"Dart {actual_dart} (framework {actual_revision}).",
            file=sys.stderr,
        )
        return 2

    analyzer_result = run(
        [
            args.flutter,
            "analyze",
            "--no-pub",
            "--no-fatal-infos",
            "--no-fatal-warnings",
        ],
        cwd=ROOT,
    )
    diagnostics, malformed = parse_diagnostics(analyzer_result.stdout)
    if malformed:
        print("Analyzer output could not be parsed safely:", file=sys.stderr)
        for item in malformed:
            print(f"  {item}", file=sys.stderr)
        print(analyzer_result.stdout, file=sys.stderr, end="")
        return 2

    remaining = allowed.copy()
    new_diagnostics: list[dict[str, Any]] = []
    diagnostics.sort(
        key=lambda item: (
            item["file"], item["line"], item["column"], item["severity"], item["code"]
        )
    )
    for diagnostic in diagnostics:
        key = fingerprint(diagnostic)
        if remaining[key] > 0:
            remaining[key] -= 1
        else:
            new_diagnostics.append(diagnostic)

    if new_diagnostics or analyzer_result.returncode != 0:
        print(
            f"Analyzer baseline validation FAILED: {len(new_diagnostics)} new diagnostic(s).",
            file=sys.stderr,
        )
        for diagnostic in new_diagnostics:
            print(
                f"  {diagnostic['file']}:{diagnostic['line']}:{diagnostic['column']}: "
                f"{diagnostic['severity']} [{diagnostic['code']}] {diagnostic['message']}",
                file=sys.stderr,
            )
        if analyzer_result.returncode != 0 and not new_diagnostics:
            print(
                f"flutter analyze exited with status {analyzer_result.returncode}.",
                file=sys.stderr,
            )
            print(analyzer_result.stdout, file=sys.stderr, end="")
        return 1

    current_counts = Counter(item["severity"] for item in diagnostics)
    removed_count = sum(remaining.values())
    print(
        "Analyzer baseline validation PASSED: "
        f"{current_counts['info']} infos, {current_counts['warning']} warnings, "
        f"{current_counts['error']} errors; no diagnostics exceed the reviewed baseline."
    )
    if removed_count:
        print(f"Historical diagnostics no longer present: {removed_count}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
