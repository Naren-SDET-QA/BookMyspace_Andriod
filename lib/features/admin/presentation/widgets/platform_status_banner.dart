import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/platform_status.dart';
import '../platform_status_providers.dart';

/// Shell body with the maintenance / broadcast banner pinned on top.
class PlatformStatusShellBody extends ConsumerWidget {
  const PlatformStatusShellBody({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status =
        ref.watch(platformStatusProvider).valueOrNull ?? PlatformStatus.none;
    if (!status.maintenanceEnabled && !status.showsBroadcast) return child;
    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: PlatformStatusBanner(status: status),
        ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: child,
          ),
        ),
      ],
    );
  }
}

class PlatformStatusBanner extends StatelessWidget {
  const PlatformStatusBanner({super.key, required this.status});

  final PlatformStatus status;

  @override
  Widget build(BuildContext context) {
    final maintenance = status.maintenanceEnabled;
    final severity = maintenance ? 'critical' : status.broadcastSeverity;
    final (Color bg, Color fg, IconData icon) = switch (severity) {
      'critical' => (
          const Color(0xFFB91C1C),
          Colors.white,
          Icons.construction_rounded,
        ),
      'warning' => (
          const Color(0xFFF59E0B),
          Colors.black87,
          Icons.warning_amber_rounded,
        ),
      _ => (
          Theme.of(context).colorScheme.primary,
          Theme.of(context).colorScheme.onPrimary,
          Icons.campaign_rounded,
        ),
    };
    final text = [
      if (maintenance) status.maintenanceText,
      if (status.showsBroadcast) status.broadcastMessage.trim(),
    ].join('  •  ');
    return Material(
      key: const Key('platform-status-banner'),
      color: bg,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: fg, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fg,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
