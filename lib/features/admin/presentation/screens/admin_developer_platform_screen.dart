import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/error_view.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../integrations/infrastructure/supabase_developer_platform_repository.dart';

final developerPlatformRepositoryProvider =
    Provider<SupabaseDeveloperPlatformRepository>((ref) {
      return SupabaseDeveloperPlatformRepository(ref.watch(supabaseProvider));
    });

class AdminDeveloperPlatformScreen extends ConsumerStatefulWidget {
  const AdminDeveloperPlatformScreen({super.key});

  @override
  ConsumerState<AdminDeveloperPlatformScreen> createState() =>
      _AdminDeveloperPlatformScreenState();
}

class _AdminDeveloperPlatformScreenState
    extends ConsumerState<AdminDeveloperPlatformScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
  late Future<List<Map<String, dynamic>>> _keys;
  late Future<List<Map<String, dynamic>>> _endpoints;
  late Future<List<Map<String, dynamic>>> _deliveries;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final repo = ref.read(developerPlatformRepositoryProvider);
    _keys = repo.apiKeys();
    _endpoints = repo.endpoints();
    _deliveries = repo.deliveries();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer platform'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'API keys'),
            Tab(text: 'Webhooks'),
            Tab(text: 'Delivery log'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_keysTab(), _endpointsTab(), _deliveriesTab()],
      ),
    );
  }

  Widget _keysTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _keys,
      builder: (context, snapshot) {
        if (snapshot.hasError) return ErrorView(message: '${snapshot.error}');
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final items = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FilledButton.icon(
              onPressed: _createKey,
              icon: const Icon(Icons.add),
              label: const Text('Create API key'),
            ),
            const SizedBox(height: 12),
            for (final item in items)
              Card(
                child: ListTile(
                  title: Text(item['name'] as String? ?? 'Unnamed key'),
                  subtitle: Text(
                    '${item['key_prefix'] ?? 'key'} · ${(item['scopes'] as List?)?.join(', ') ?? ''}',
                  ),
                  trailing: item['revoked_at'] == null
                      ? IconButton(
                          tooltip: 'Revoke',
                          onPressed: () => _revokeKey(item['id'] as String),
                          icon: const Icon(Icons.block_outlined),
                        )
                      : const Text('Revoked'),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _endpointsTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _endpoints,
      builder: (context, snapshot) {
        if (snapshot.hasError) return ErrorView(message: '${snapshot.error}');
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final items = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FilledButton.icon(
              onPressed: _editEndpoint,
              icon: const Icon(Icons.add_link),
              label: const Text('Add webhook endpoint'),
            ),
            const SizedBox(height: 12),
            for (final item in items)
              Card(
                child: ListTile(
                  title: Text(item['name'] as String? ?? 'Unnamed endpoint'),
                  subtitle: Text(
                    '${item['endpoint_url'] ?? ''}\nEvents: ${(item['event_types'] as List?)?.join(', ') ?? ''}',
                  ),
                  isThreeLine: true,
                  trailing: Icon(
                    item['enabled'] == true ? Icons.check : Icons.pause,
                  ),
                  onTap: () => _editEndpoint(item),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _deliveriesTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _deliveries,
      builder: (context, snapshot) {
        if (snapshot.hasError) return ErrorView(message: '${snapshot.error}');
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final items = snapshot.data!;
        if (items.isEmpty)
          return const Center(child: Text('No deliveries yet.'));
        return RefreshIndicator(
          onRefresh: () async {
            setState(_reload);
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                tileColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                title: Text(item['event_type'] as String? ?? 'event'),
                subtitle: Text(
                  '${item['status']} · attempts ${item['attempt_count']}',
                ),
                trailing: Text('${item['response_status'] ?? '—'}'),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _createKey() async {
    final name = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create API key'),
        content: TextField(
          controller: name,
          decoration: const InputDecoration(labelText: 'Key name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (created != true || name.text.trim().isEmpty || !mounted) {
      name.dispose();
      return;
    }
    try {
      final value = await ref
          .read(developerPlatformRepositoryProvider)
          .createKey(name.text.trim(), const ['bookings:read', 'venues:read']);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Copy this key now'),
          content: SelectableText(value['secret'] as String? ?? ''),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      setState(_reload);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      name.dispose();
    }
  }

  Future<void> _revokeKey(String id) async {
    await ref.read(developerPlatformRepositoryProvider).revokeKey(id);
    setState(_reload);
  }

  Future<void> _editEndpoint([Map<String, dynamic>? existing]) async {
    final name = TextEditingController(
      text: existing?['name'] as String? ?? '',
    );
    final url = TextEditingController(
      text: existing?['endpoint_url'] as String? ?? '',
    );
    final secret = TextEditingController(
      text: existing?['secret_reference'] as String? ?? '',
    );
    var enabled = existing?['enabled'] as bool? ?? false;
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            existing == null ? 'Add webhook endpoint' : 'Edit webhook endpoint',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: url,
                  decoration: const InputDecoration(
                    labelText: 'HTTPS endpoint',
                  ),
                ),
                TextField(
                  controller: secret,
                  decoration: const InputDecoration(
                    labelText: 'Server secret reference',
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: enabled,
                  onChanged: (value) => setDialogState(() => enabled = value),
                  title: const Text('Enabled'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (save == true && name.text.trim().isNotEmpty && mounted) {
      try {
        await ref
            .read(developerPlatformRepositoryProvider)
            .saveEndpoint(
              id: existing?['id'] as String?,
              name: name.text.trim(),
              endpointUrl: url.text.trim(),
              secretReference: secret.text.trim(),
              eventTypes: const [
                'booking.created',
                'booking.confirmed',
                'booking.cancelled',
              ],
              enabled: enabled,
            );
        setState(_reload);
      } catch (error) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
    name.dispose();
    url.dispose();
    secret.dispose();
  }
}
