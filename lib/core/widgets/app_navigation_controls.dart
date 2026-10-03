import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';
import '../theme/app_theme.dart';

/// Reusable global Back + Home navigation control for BookMySpace.
///
/// Provides a unified, accessible, and responsive Back and Home button pair:
/// - Back: steps back via [Navigator.pop] if [Navigator.canPop], or falls back
///   safely to canonical [AppRoutes.home].
/// - Home: safely navigates to canonical [AppRoutes.home] via [GoRouter.go]
///   to switch to the root shell and clear any nested/pushed route stack.
///
/// Designed for use in:
/// - [AppBar.leading] (with [leadingWidth] = [kLeadingWidth])
/// - [SliverAppBar.leading]
/// - Custom screen headers and hero banners
///
/// Hides the Back button automatically on the canonical Home screen ([AppRoutes.home])
/// and respects auth/root states to prevent invalid pops.
class AppNavigationControls extends StatelessWidget {
  const AppNavigationControls({
    super.key,
    this.showBack = true,
    this.showHome = true,
    this.onBack,
    this.onHome,
    this.backKey,
    this.homeKey,
    this.color,
    this.backgroundColor,
    this.useCapsule = true,
    this.iconSize = 20.0,
  });

  /// Standard width when placed in [AppBar.leading] or [SliverAppBar.leading].
  static const double kLeadingWidth = 92.0;

  /// Width when only a single button is shown.
  static const double kSingleLeadingWidth = 48.0;

  /// Whether the Back button should be shown (if allowed by current route state).
  final bool showBack;

  /// Whether the Home button should be shown.
  final bool showHome;

  /// Optional custom callback for the Back button.
  final VoidCallback? onBack;

  /// Optional custom callback for the Home button.
  final VoidCallback? onHome;

  /// Optional key for the back button widget.
  final Key? backKey;

  /// Optional key for the home button widget.
  final Key? homeKey;

  /// Foreground icon color. Defaults to theme icon color or [AppTheme.textSecondary].
  final Color? color;

  /// Background color for the capsule container.
  final Color? backgroundColor;

  /// If true, wraps the controls in a rounded glass/surface capsule container.
  final bool useCapsule;

  /// Size of the icons.
  final double iconSize;

  /// Factory constructor for just the Back button.
  const AppNavigationControls.back({
    super.key,
    this.onBack,
    this.backKey,
    this.homeKey,
    this.color,
    this.backgroundColor,
    this.useCapsule = false,
    this.iconSize = 20.0,
  })  : showBack = true,
        showHome = false,
        onHome = null;

  /// Factory constructor for just the Home button.
  const AppNavigationControls.home({
    super.key,
    this.onHome,
    this.backKey,
    this.homeKey,
    this.color,
    this.backgroundColor,
    this.useCapsule = false,
    this.iconSize = 20.0,
  })  : showBack = false,
        showHome = true,
        onBack = null;

  @override
  Widget build(BuildContext context) {
    String location = '';
    try {
      final state = GoRouterState.of(context);
      location = state.matchedLocation;
    } catch (_) {
      try {
        final router = GoRouter.maybeOf(context);
        location =
            router?.routerDelegate.currentConfiguration.uri.toString() ?? '';
      } catch (_) {}
    }

    final isHome = location == AppRoutes.home ||
        location == AppRoutes.root ||
        location == '/home' ||
        location == '/';

    // Rule 9: On the Home/root screen, do not show a Back button.
    final effectiveShowBack = showBack && (!isHome || onBack != null);
    // On the Home screen itself, do not show a redundant Home button unless custom.
    final effectiveShowHome = showHome && (!isHome || onHome != null);

    if (!effectiveShowBack && !effectiveShowHome) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final effectiveColor = color ??
        (isDark
            ? Colors.white
            : (theme.appBarTheme.foregroundColor ?? AppTheme.textSecondary));

    void handleBack() {
      if (onBack != null) {
        onBack!();
        return;
      }
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        context.go(AppRoutes.home);
      }
    }

    void handleHome() {
      if (onHome != null) {
        onHome!();
        return;
      }
      // Rule 14: Home must always safely navigate to the canonical Home route
      // and clear/replace the navigation stack so the user does not get trapped.
      context.go(AppRoutes.home);
    }

    final buttonStyle = IconButton.styleFrom(
      minimumSize: const Size(32, 32),
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );

    final backButton = IconButton(
      key: backKey ?? const Key('global_back_button'),
      tooltip: 'Back',
      icon: const Icon(Icons.arrow_back_rounded),
      iconSize: iconSize,
      color: effectiveColor,
      style: buttonStyle,
      onPressed: handleBack,
    );

    final homeButton = IconButton(
      key: homeKey ?? const Key('global_home_button'),
      tooltip: 'Home',
      icon: const Icon(Icons.home_rounded),
      iconSize: iconSize,
      color: effectiveColor,
      style: buttonStyle,
      onPressed: handleHome,
    );

    if (useCapsule && effectiveShowBack && effectiveShowHome) {
      return Padding(
        padding: const EdgeInsets.only(left: 6.0),
        child: Center(
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            decoration: BoxDecoration(
              color: backgroundColor ??
                  (isDark
                      ? Colors.white.withValues(alpha: 0.10)
                      : Colors.black.withValues(alpha: 0.05)),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.10),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                backButton,
                Container(
                  width: 1,
                  height: 14,
                  margin: const EdgeInsets.symmetric(horizontal: 2.0),
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.18)
                      : Colors.black.withValues(alpha: 0.12),
                ),
                homeButton,
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (effectiveShowBack) backButton,
          if (effectiveShowHome) homeButton,
        ],
      ),
    );
  }
}
