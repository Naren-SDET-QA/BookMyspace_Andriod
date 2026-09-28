import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../daily_report_providers.dart';

class DailyReportPreferenceCard extends ConsumerWidget {
  const DailyReportPreferenceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(dailyReportEnabledProvider);
    return Card(
      child: enabled.when(
        loading: () => const ListTile(
          leading: Icon(Icons.schedule_outlined),
          title: Text('Daily report push'),
          trailing: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (error, _) => ListTile(
          leading: const Icon(Icons.schedule_outlined),
          title: const Text('Daily report push'),
          subtitle: const Text('Could not load this preference'),
          trailing: IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(dailyReportEnabledProvider),
          ),
        ),
        data: (value) => SwitchListTile(
          secondary: const Icon(Icons.schedule_outlined),
          title: const Text('Daily report push'),
          subtitle: const Text('Receive your booking summary at 9:00 PM'),
          value: value,
          onChanged: (next) async {
            await ref.read(dailyReportRepositoryProvider).save(enabled: next);
            ref.invalidate(dailyReportEnabledProvider);
          },
        ),
      ),
    );
  }
}
