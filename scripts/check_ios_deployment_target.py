#!/usr/bin/env python3
"""Fail-closed iOS minimum-version check; never edits project settings."""

from __future__ import annotations

import argparse
import json
import plistlib
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
# Release policy: iOS 14.0 was selected for PROD because file_picker_darwin
# requires it. Any future policy change must be an explicit owner decision.
MINIMUM_IOS = (14, 0, 0)
MINIMUM_IOS_TEXT = "14.0"


def version_tuple(value: str) -> tuple[int, ...] | None:
    try:
        parts = tuple(int(part) for part in value.split("."))
    except ValueError:
        return None
    if not parts:
        return None
    return parts + (0,) * max(0, 3 - len(parts))


def ignored_manifest(path: Path, package_root: Path) -> bool:
    relative_parts = path.relative_to(package_root).parts
    return any(
        part.lower() in {"example", "examples", "test", "tests", "build", ".dart_tool"}
        for part in relative_parts
    )


def plugin_minimums(errors: list[str]) -> None:
    metadata_path = ROOT / ".flutter-plugins-dependencies"
    if not metadata_path.is_file():
        errors.append(
            "Missing .flutter-plugins-dependencies; run `flutter pub get` with the pinned SDK first."
        )
        return

    try:
        metadata = json.loads(metadata_path.read_text())
    except (OSError, json.JSONDecodeError) as error:
        errors.append(f"Cannot read {metadata_path.relative_to(ROOT)}: {error}")
        return

    plugins = metadata.get("plugins", {}).get("ios", [])
    swift_minimum = re.compile(
        r"\.iOS\(\s*(?:[\"']([0-9]+(?:\.[0-9]+)*)[\"']|\.v([0-9]+))\s*\)",
        re.DOTALL,
    )
    pod_minimums = (
        re.compile(
            r"\b(?:s|spec)\.ios\.deployment_target\s*=\s*[\"']([0-9]+(?:\.[0-9]+)*)[\"']"
        ),
        re.compile(
            r"\b(?:s|spec)\.platform\s*=\s*:ios\s*,\s*[\"']([0-9]+(?:\.[0-9]+)*)[\"']"
        ),
    )

    for plugin in plugins:
        name = str(plugin.get("name", "unknown plugin"))
        raw_path = str(plugin.get("path", ""))
        if not raw_path:
            errors.append(f"iOS plugin {name} has no package path in .flutter-plugins-dependencies.")
            continue
        package_root = Path(raw_path)
        if not package_root.is_dir():
            errors.append(f"iOS plugin {name} has a missing package path: {package_root}")
            continue

        manifests = list(package_root.rglob("Package.swift"))
        podspecs = list(package_root.rglob("*.podspec"))
        for manifest in manifests:
            relative = manifest.relative_to(package_root)
            if ignored_manifest(manifest, package_root):
                continue
            if len(relative.parts) > 1 and relative.parts[0] not in {"ios", "darwin"}:
                continue
            contents = manifest.read_text(errors="replace")
            for match in swift_minimum.finditer(contents):
                required_text = match.group(1) or f"{match.group(2)}.0"
                line_number = contents.count("\n", 0, match.start()) + 1
                check_plugin_minimum(
                    errors,
                    name,
                    package_root,
                    manifest,
                    line_number,
                    required_text,
                )

        for podspec in podspecs:
            relative = podspec.relative_to(package_root)
            if ignored_manifest(podspec, package_root):
                continue
            if len(relative.parts) > 1 and relative.parts[0] not in {"ios", "darwin"}:
                continue
            contents = podspec.read_text(errors="replace")
            for pattern in pod_minimums:
                for match in pattern.finditer(contents):
                    line_number = contents.count("\n", 0, match.start()) + 1
                    check_plugin_minimum(
                        errors,
                        name,
                        package_root,
                        podspec,
                        line_number,
                        match.group(1),
                    )


def check_plugin_minimum(
    errors: list[str],
    plugin: str,
    package_root: Path,
    manifest: Path,
    line_number: int,
    required_text: str,
) -> None:
    required = version_tuple(required_text)
    if required is None or required <= MINIMUM_IOS:
        return
    package_version = package_root.name
    location = f"{manifest.relative_to(ROOT) if manifest.is_relative_to(ROOT) else manifest}:{line_number}"
    errors.append(
        f"Detected plugin {plugin} ({package_version}) requires iOS {required_text}; "
        f"configured PROD minimum is iOS {MINIMUM_IOS_TEXT}. Source: {location}. "
        "Do not auto-raise the deployment target; obtain an owner decision and update the policy/configuration."
    )


def check_configured_minimum(errors: list[str]) -> None:
    podfile = ROOT / "ios/Podfile"
    pod_text = podfile.read_text()
    pod_match = re.search(r"^\s*platform\s+:ios,\s*[\"']([0-9.]+)[\"']", pod_text, re.MULTILINE)
    if not pod_match:
        errors.append("Cannot determine the iOS platform from ios/Podfile.")
    elif version_tuple(pod_match.group(1)) != MINIMUM_IOS:
        errors.append(
            f"ios/Podfile configures iOS {pod_match.group(1)}, but release policy is iOS {MINIMUM_IOS_TEXT}. "
            "Owner decision required before changing the minimum."
        )

    project_path = ROOT / "ios/Runner.xcodeproj/project.pbxproj"
    project_text = project_path.read_text()
    target_matches = list(
        re.finditer(r"IPHONEOS_DEPLOYMENT_TARGET\s*=\s*([0-9.]+);", project_text)
    )
    if not target_matches:
        errors.append("No IPHONEOS_DEPLOYMENT_TARGET settings found in ios/Runner.xcodeproj/project.pbxproj.")
    for match in target_matches:
        if version_tuple(match.group(1)) != MINIMUM_IOS:
            line_number = project_text.count("\n", 0, match.start()) + 1
            errors.append(
                f"ios/Runner.xcodeproj/project.pbxproj:{line_number} configures iOS {match.group(1)}; "
                f"release policy is iOS {MINIMUM_IOS_TEXT}. Owner decision required before changing the minimum."
            )

    for config_path in (ROOT / "ios/Flutter").glob("*.xcconfig"):
        for line_number, line in enumerate(config_path.read_text(errors="replace").splitlines(), 1):
            match = re.search(r"IPHONEOS_DEPLOYMENT_TARGET\s*=\s*([0-9.]+)", line)
            if match and version_tuple(match.group(1)) != MINIMUM_IOS:
                errors.append(
                    f"{config_path.relative_to(ROOT)}:{line_number} configures iOS {match.group(1)}; "
                    f"release policy is iOS {MINIMUM_IOS_TEXT}."
                )

    info_path = ROOT / "ios/Runner/Info.plist"
    with info_path.open("rb") as info_file:
        info = plistlib.load(info_file)
    source_minimum = info.get("MinimumOSVersion")
    if source_minimum and version_tuple(str(source_minimum)) != MINIMUM_IOS:
        errors.append(
            f"ios/Runner/Info.plist declares MinimumOSVersion {source_minimum}; "
            f"release policy is iOS {MINIMUM_IOS_TEXT}."
        )


def check_generated_build(errors: list[str]) -> None:
    generated_manifest = (
        ROOT
        / "ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift"
    )
    if not generated_manifest.is_file():
        errors.append(
            "Flutter-generated Swift package manifest is missing after the iOS build: "
            "ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift"
        )
    else:
        text = generated_manifest.read_text(errors="replace")
        match = re.search(r"\.iOS\(\s*[\"']([0-9.]+)[\"']\s*\)", text)
        if not match or version_tuple(match.group(1)) != MINIMUM_IOS:
            found = match.group(1) if match else "not declared"
            errors.append(
                f"Flutter-generated Swift package targets iOS {found}; expected {MINIMUM_IOS_TEXT}. "
                "Regenerate with the pinned Flutter SDK by rebuilding; do not edit ephemeral files by hand."
            )

    app_info_path = ROOT / "build/ios/iphoneos/Runner.app/Info.plist"
    if not app_info_path.is_file():
        errors.append(f"Built iOS app metadata is missing: {app_info_path.relative_to(ROOT)}")
    else:
        with app_info_path.open("rb") as info_file:
            app_info = plistlib.load(info_file)
        actual = str(app_info.get("MinimumOSVersion", "not declared"))
        if version_tuple(actual) != MINIMUM_IOS:
            errors.append(
                f"Built Runner.app MinimumOSVersion is {actual}; expected {MINIMUM_IOS_TEXT}."
            )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--after-build",
        action="store_true",
        help="also verify Flutter-generated Swift package and built Runner.app deployment versions",
    )
    args = parser.parse_args()

    errors: list[str] = []
    check_configured_minimum(errors)
    plugin_minimums(errors)
    if args.after_build:
        check_generated_build(errors)

    if errors:
        print("iOS deployment-target validation FAILED:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    phase = "source and built app" if args.after_build else "source configuration and plugins"
    print(f"iOS deployment-target validation passed ({phase}); PROD minimum is iOS {MINIMUM_IOS_TEXT}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
