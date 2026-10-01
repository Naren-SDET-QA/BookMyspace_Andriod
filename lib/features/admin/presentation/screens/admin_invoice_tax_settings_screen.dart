import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/auth/presentation/auth_providers.dart';

class AdminInvoiceTaxSettingsScreen extends ConsumerStatefulWidget {
  const AdminInvoiceTaxSettingsScreen({super.key});

  @override
  ConsumerState<AdminInvoiceTaxSettingsScreen> createState() =>
      _AdminInvoiceTaxSettingsScreenState();
}

class _AdminInvoiceTaxSettingsScreenState
    extends ConsumerState<AdminInvoiceTaxSettingsScreen> {
  final _prefix = TextEditingController();
  final _sac = TextEditingController();
  final _gstin = TextEditingController();
  final _pan = TextEditingController();
  final _state = TextEditingController();
  late Future<void> _loadFuture;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadFuture = _load();
  }

  Future<void> _load() async {
    final row = await ref
        .read(supabaseProvider)
        .rpc<Map<String, dynamic>>('get_invoice_tax_defaults');
    _prefix.text = row['invoice_prefix']?.toString() ?? 'BMS';
    _sac.text = row['sac_code']?.toString() ?? '997212';
    _gstin.text = row['default_gstin']?.toString() ?? '';
    _pan.text = row['default_pan']?.toString() ?? '';
    _state.text = row['default_state']?.toString() ?? '';
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(supabaseProvider)
          .rpc<Map<String, dynamic>>(
            'save_invoice_tax_defaults',
            params: {
              'p_config': {
                'invoice_prefix': _prefix.text.trim(),
                'sac_code': _sac.text.trim(),
                'default_gstin': _gstin.text.trim(),
                'default_pan': _pan.text.trim(),
                'default_state': _state.text.trim(),
              },
            },
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice tax defaults saved')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _prefix.dispose();
    _sac.dispose();
    _gstin.dispose();
    _pan.dispose();
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('GST invoice defaults')),
    body: FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Could not load defaults: ${snapshot.error}'),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'These values are used only when a venue has not supplied an override.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _prefix,
              decoration: const InputDecoration(labelText: 'Invoice prefix'),
            ),
            TextField(
              controller: _sac,
              decoration: const InputDecoration(labelText: 'Default SAC code'),
            ),
            TextField(
              controller: _gstin,
              decoration: const InputDecoration(labelText: 'Default GSTIN'),
            ),
            TextField(
              controller: _pan,
              decoration: const InputDecoration(labelText: 'Default PAN'),
            ),
            TextField(
              controller: _state,
              decoration: const InputDecoration(
                labelText: 'Default seller state',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Saving...' : 'Save defaults'),
            ),
          ],
        );
      },
    ),
  );
}
