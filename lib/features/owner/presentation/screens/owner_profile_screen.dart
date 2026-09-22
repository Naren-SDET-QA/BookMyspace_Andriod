import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/error_view.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../owner_providers.dart';

/// Production-safe owner profile editor for the Phase-1 route.
///
/// It only edits fields represented by the PROD owner model and writes through
/// the authenticated Supabase session. It does not restore the Phase-1 auth
/// or owner repository implementation.
class OwnerProfileScreen extends ConsumerStatefulWidget {
  const OwnerProfileScreen({super.key});

  @override
  ConsumerState<OwnerProfileScreen> createState() => _OwnerProfileScreenState();
}

class _OwnerProfileScreenState extends ConsumerState<OwnerProfileScreen> {
  final _nameController = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(currentOwnerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Owner profile')),
      body: owner.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(message: error.toString()),
        data: (value) {
          if (value == null) {
            return const Center(child: Text('Owner profile not found.'));
          }
          if (!_loaded) {
            _loaded = true;
            _nameController.text = value.name;
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: value.email,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving
                    ? null
                    : () => _save(value.id, _nameController.text),
                child: Text(_saving ? 'Saving…' : 'Save profile'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _save(String ownerId, String name) async {
    final value = name.trim();
    if (value.isEmpty) return;
    setState(() => _saving = true);
    try {
      final client = ref.read(supabaseProvider);
      await client.from('owner_profiles').update({'name': value}).eq('id', ownerId);
      ref.invalidate(currentOwnerProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Owner profile saved.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
