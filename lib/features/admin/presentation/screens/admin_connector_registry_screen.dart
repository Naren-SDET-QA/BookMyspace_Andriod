import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/error_view.dart';
import '../../../auth/presentation/auth_providers.dart';

class AdminConnectorRegistryScreen extends ConsumerStatefulWidget {
  const AdminConnectorRegistryScreen({super.key});

  @override
  ConsumerState<AdminConnectorRegistryScreen> createState() =>
      _AdminConnectorRegistryScreenState();
}

class _AdminConnectorRegistryScreenState
    extends ConsumerState<AdminConnectorRegistryScreen> {
  late Future<List<Map<String, dynamic>>> _integrations;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _integrations = ref
        .read(supabaseProvider)
        .from('integrations')
        .select(
          'id,name,slug,type,provider,description,base_url,authentication_type,configuration,enabled,status,environment',
        )
        .isFilter('archived_at', null)
        .order('display_order');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connector registry')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _integrations,
        builder: (context, snapshot) {
          if (snapshot.hasError) return ErrorView(message: '${snapshot.error}');
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final items = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => setState(_reload),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Credentials stay in server-side secret configuration. The registry stores connector metadata and secret references only.',
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _edit,
                  icon: const Icon(Icons.add_link),
                  label: const Text('Add connector'),
                ),
                const SizedBox(height: 12),
                for (final item in items)
                  Card(
                    child: ListTile(
                      title: Text(
                        item['name'] as String? ?? 'Unnamed connector',
                      ),
                      subtitle: Text(
                        '${item['provider'] ?? ''} · ${item['type'] ?? ''}\n${item['base_url'] ?? 'No endpoint'}',
                      ),
                      isThreeLine: true,
                      leading: Icon(
                        item['enabled'] == true
                            ? Icons.check_circle
                            : Icons.pause_circle,
                      ),
                      onTap: () => _edit(item),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _edit([Map<String, dynamic>? existing]) async {
    final name = TextEditingController(
      text: existing?['name'] as String? ?? '',
    );
    final provider = TextEditingController(
      text: existing?['provider'] as String? ?? '',
    );
    final slug = TextEditingController(
      text: existing?['slug'] as String? ?? '',
    );
    final url = TextEditingController(
      text: existing?['base_url'] as String? ?? '',
    );
    final secretReference = TextEditingController(
      text:
          (existing?['configuration'] as Map?)?['secret_reference']
              as String? ??
          '',
    );
    var type = existing?['type'] as String? ?? 'WEBHOOK';
    var auth = existing?['authentication_type'] as String? ?? 'NONE';
    var enabled = existing?['enabled'] as bool? ?? false;
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add connector' : 'Edit connector'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: slug,
                  decoration: const InputDecoration(labelText: 'Slug'),
                ),
                TextField(
                  controller: provider,
                  decoration: const InputDecoration(labelText: 'Provider'),
                ),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items:
                      const [
                            'WEBHOOK',
                            'REST_API',
                            'GRAPHQL',
                            'MCP',
                            'SUPABASE_RPC',
                          ]
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                  onChanged: (value) =>
                      setDialogState(() => type = value ?? type),
                ),
                TextField(
                  controller: url,
                  decoration: const InputDecoration(labelText: 'Base URL'),
                ),
                DropdownButtonFormField<String>(
                  value: auth,
                  decoration: const InputDecoration(
                    labelText: 'Authentication',
                  ),
                  items:
                      const [
                            'NONE',
                            'API_KEY',
                            'BEARER_TOKEN',
                            'OAUTH2',
                            'CUSTOM_HEADER',
                          ]
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                  onChanged: (value) =>
                      setDialogState(() => auth = value ?? auth),
                ),
                TextField(
                  controller: secretReference,
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
    if (save == true &&
        name.text.trim().isNotEmpty &&
        slug.text.trim().isNotEmpty &&
        mounted) {
      try {
        final client = ref.read(supabaseProvider);
        await client.from('integrations').upsert({
          if (existing?['id'] != null) 'id': existing!['id'],
          'name': name.text.trim(),
          'slug': slug.text.trim(),
          'provider': provider.text.trim().isEmpty
              ? null
              : provider.text.trim(),
          'type': type,
          'base_url': url.text.trim().isEmpty ? null : url.text.trim(),
          'authentication_type': auth,
          'configuration': {
            if (secretReference.text.trim().isNotEmpty)
              'secret_reference': secretReference.text.trim(),
          },
          'enabled': enabled,
          'status': enabled ? 'enabled' : 'disabled',
          'environment': 'development',
          'created_by': client.auth.currentUser?.id,
        }, onConflict: 'slug');
        setState(_reload);
      } catch (error) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
    name.dispose();
    provider.dispose();
    slug.dispose();
    url.dispose();
    secretReference.dispose();
  }
}
