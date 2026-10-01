import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/platform_status.dart';
import '../platform_status_providers.dart';

/// Admin settings card: maintenance mode + broadcast banner.
class PlatformStatusSection extends ConsumerStatefulWidget {
  const PlatformStatusSection({super.key});

  @override
  ConsumerState<PlatformStatusSection> createState() =>
      _PlatformStatusSectionState();
}

class _PlatformStatusSectionState extends ConsumerState<PlatformStatusSection> {
  PlatformStatus? _draft;
  final _maintenanceMessage = TextEditingController();
  final _broadcastMessage = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _maintenanceMessage.dispose();
    _broadcastMessage.dispose();
    super.dispose();
  }

  void _seed(PlatformStatus status) {
    if (_draft != null) return;
    _draft = status;
    _maintenanceMessage.text = status.maintenanceMessage;
    _broadcastMessage.text = status.broadcastMessage;
  }

  PlatformStatus _current() {
    final d = _draft ?? PlatformStatus.none;
    return PlatformStatus(
      maintenanceEnabled: d.maintenanceEnabled,
      maintenanceMessage: _maintenanceMessage.text,
      broadcastEnabled: d.broadcastEnabled,
      broadcastMessage: _broadcastMessage.text,
      broadcastSeverity: d.broadcastSeverity,
    );
  }

  void _update(PlatformStatus Function(PlatformStatus) change) =>
      setState(() => _draft = change(_current()));

  Future<void> _save() async {
    final next = _current();
    final wasOn =
        ref.read(platformStatusProvider).valueOrNull?.maintenanceEnabled ??
            false;
    if (next.maintenanceEnabled && !wasOn) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Turn on maintenance mode?'),
          content: const Text(
            'Customers will not be able to book or enroll until you turn it '
            'off. Existing bookings are not affected.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Turn on'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(platformStatusControllerProvider).save(next);
      messenger.showSnackBar(
        const SnackBar(content: Text('Platform status saved')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(platformStatusProvider);
    final loaded = async.valueOrNull;
    if (loaded != null) _seed(loaded);
    final d = _draft ?? PlatformStatus.none;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Maintenance & broadcast',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              key: const Key('admin-maintenance-switch'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Maintenance mode'),
              subtitle: const Text('Pauses all new bookings and enrollments'),
              value: d.maintenanceEnabled,
              onChanged: (v) => _update(
                (c) => PlatformStatus(
                  maintenanceEnabled: v,
                  maintenanceMessage: c.maintenanceMessage,
                  broadcastEnabled: c.broadcastEnabled,
                  broadcastMessage: c.broadcastMessage,
                  broadcastSeverity: c.broadcastSeverity,
                ),
              ),
            ),
            TextField(
              controller: _maintenanceMessage,
              decoration: const InputDecoration(
                labelText: 'Maintenance message',
                hintText: 'We are upgrading payments. Back by 6 PM.',
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              key: const Key('admin-broadcast-switch'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Broadcast banner'),
              subtitle: const Text('Shown at the top of the app for everyone'),
              value: d.broadcastEnabled,
              onChanged: (v) => _update(
                (c) => PlatformStatus(
                  maintenanceEnabled: c.maintenanceEnabled,
                  maintenanceMessage: c.maintenanceMessage,
                  broadcastEnabled: v,
                  broadcastMessage: c.broadcastMessage,
                  broadcastSeverity: c.broadcastSeverity,
                ),
              ),
            ),
            TextField(
              controller: _broadcastMessage,
              decoration: const InputDecoration(labelText: 'Banner message'),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'info', label: Text('Info')),
                ButtonSegment(value: 'warning', label: Text('Warning')),
                ButtonSegment(value: 'critical', label: Text('Critical')),
              ],
              selected: {d.broadcastSeverity},
              onSelectionChanged: (s) => _update(
                (c) => PlatformStatus(
                  maintenanceEnabled: c.maintenanceEnabled,
                  maintenanceMessage: c.maintenanceMessage,
                  broadcastEnabled: c.broadcastEnabled,
                  broadcastMessage: c.broadcastMessage,
                  broadcastSeverity: s.first,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                key: const Key('admin-platform-status-save'),
                onPressed: _saving ? null : _save,
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
