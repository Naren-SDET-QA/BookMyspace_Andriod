import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';

/// A "Watch" affordance for a Home section that carries video links.
///
/// Videos are **links, not uploads**. Tapping hands the URL to the platform's
/// own player, which keeps the feed fast — nothing is decoded while the
/// customer scrolls — and means any source the device understands works: a
/// direct file, YouTube, or a CDN. Playback happens in an app that already
/// handles every format, instead of a half-built in-app player that could only
/// cope with direct files.
class HomeVideoPill extends StatelessWidget {
  const HomeVideoPill({super.key, required this.videos, this.onOpen});

  final List<String> videos;

  /// Overrides how a link is opened, so tests stay off the platform.
  final Future<bool> Function(Uri uri)? onOpen;

  /// Whether a stored value is a URL we are willing to hand to the platform.
  ///
  /// Only `http` and `https` are accepted. `javascript:`, `file:` and
  /// `intent:` style URLs are rejected, so a value that reached the config by
  /// any route can never become a local file disclosure or an execution
  /// primitive on the device that renders it.
  static bool isPlayable(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return false;
    final scheme = uri.scheme.toLowerCase();
    return (scheme == 'http' || scheme == 'https') && uri.host.isNotEmpty;
  }

  /// Only the links that are safe to open.
  static List<String> playable(List<String> videos) =>
      videos.where(isPlayable).toList(growable: false);

  Future<void> _open(BuildContext context) async {
    final usable = playable(videos);
    if (usable.isEmpty) {
      _report(context);
      return;
    }

    final uri = Uri.parse(usable.first);
    final handler = onOpen;
    var launched = false;
    try {
      launched = handler != null
          ? await handler(uri)
          : await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // No handler installed, or the platform refused. Reported, never thrown:
      // a missing video app must not take the screen down.
      launched = false;
    }
    if (!launched && context.mounted) _report(context);
  }

  void _report(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).homeVideoUnavailable)),
      );
  }

  @override
  Widget build(BuildContext context) {
    if (videos.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final count = videos.length;

    return Align(
      alignment: Alignment.centerLeft,
      child: ActionChip(
        avatar: const Icon(
          Icons.play_circle_fill_rounded,
          size: 18,
          color: AppTheme.brand,
        ),
        label: Text(
          count > 1 ? '${l10n.homeWatch} · $count' : l10n.homeWatch,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        onPressed: () => _open(context),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
