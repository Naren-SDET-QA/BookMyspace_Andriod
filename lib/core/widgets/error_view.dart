import 'package:flutter/material.dart';

import '../errors/app_exceptions.dart';
import '../localization/app_localizations.dart';

/// Full-screen error state with a retry button.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                _friendlyMessage(message),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 24),
                FilledButton.tonalIcon(
                  onPressed: onRetry,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(l10n.tryAgain),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _friendlyMessage(String message) {
    final lower = message.toLowerCase();
    final technical = lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('clientexception') ||
        lower.contains('connection refused') ||
        lower.contains('xmlhttprequest');
    if (technical) return mapError(Exception(message)).message;
    return message;
  }
}
