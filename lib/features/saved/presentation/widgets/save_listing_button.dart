import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/saved_item.dart';
import '../saved_items_providers.dart';

/// Heart toggle that saves a course or institute to the Saved screen.
class SaveListingButton extends ConsumerStatefulWidget {
  const SaveListingButton({super.key, required this.type, required this.id});

  final SavedItemType type;
  final String id;

  @override
  ConsumerState<SaveListingButton> createState() => _SaveListingButtonState();
}

class _SaveListingButtonState extends ConsumerState<SaveListingButton> {
  bool _busy = false;

  Future<void> _toggle(bool saved) async {
    if (ref.read(currentUserProvider) == null) {
      context.push(AppRoutes.login);
      return;
    }
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(savedItemsControllerProvider)
          .toggle(widget.type, widget.id, saved: saved);
      messenger.showSnackBar(
        SnackBar(content: Text(saved ? 'Removed from Saved' : 'Saved')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ids = ref.watch(savedItemIdsProvider).valueOrNull;
    final saved = ids?[widget.type]?.contains(widget.id) ?? false;
    return IconButton(
      key: Key('save-${widget.type.dbValue}-${widget.id}'),
      tooltip: saved ? 'Remove from Saved' : 'Save',
      onPressed: _busy || widget.id.isEmpty ? null : () => _toggle(saved),
      icon: Icon(
        saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        color: saved ? Colors.redAccent : null,
      ),
    );
  }
}
