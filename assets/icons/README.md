# App Icons & Splash Screen Assets

## Canonical brand assets

`bookmyspace_logo.svg` is the Flutter source equivalent of the canonical
Android `ic_bms_logo.xml` mark. `bookmyspace_logo.png` is its 1024px raster
export used by Flutter and the iOS asset catalog. `splash_icon.svg` points to
the same visual mark for any SVG-based splash tooling.

## Generating Icons & Splash Screens

### Prerequisites

```bash
# Install the CLI tools
dart pub global activate flutter_launcher_icons
dart pub global activate flutter_native_splash
```

### Generate App Icons

```bash
# From project root
flutter pub run flutter_launcher_icons
```

This will generate:
- Android: mipmap-*/ic_launcher.png + adaptive icons
- iOS: AppIcon.appiconset/*
- Web: icons/icon-*.png in web/

### Generate Splash Screen

```bash
# From project root
flutter pub run flutter_native_splash:create
```

This will generate:
- Android: drawable*/launch_screen.xml + splash images
- iOS: LaunchScreen.storyboard + images
- Web: splash images in web/

## Asset Requirements

| Asset | Size | Format | Notes |
|-------|------|--------|-------|
| `bookmyspace_logo.png` | 1024x1024 | PNG | Shared Flutter/iOS brand mark |
| `bookmyspace_logo.svg` | 120x120 viewBox | SVG | Source vector equivalent of Android `ic_bms_logo.xml` |
| `splash_icon.svg` | 120x120 viewBox | SVG | Same canonical mark for splash tooling |

## Color Reference

- Primary Brand: `#00C9A7` (Electric Teal)
- Primary Action: `#2979FF` (Royal Blue)
- Dark Canvas: `#081A2B` (Deep Navy)
- Logo Gradient: `#10B981` → `#38BDF8` → `#818CF8`

## Quick Start

1. Keep `bookmyspace_logo.svg` aligned with the Android source mark.
2. Regenerate `bookmyspace_logo.png` and platform asset-catalog sizes from it.
3. Verify the splash screen and launcher on device/emulator.

## Testing

```bash
# Test icons
flutter run --debug

# Test splash screen (cold start)
flutter run --release
```
