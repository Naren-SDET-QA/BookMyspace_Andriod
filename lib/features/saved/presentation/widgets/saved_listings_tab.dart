import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../domain/saved_item.dart';
import '../saved_items_providers.dart';
import 'save_listing_button.dart';

/// Saved courses or institutes, newest first.
class SavedListingsTab extends ConsumerWidget {
  const SavedListingsTab({super.key, required this.type});

  final SavedItemType type;

  String _route(String id) => switch (type) {
        SavedItemType.course => '/courses/$id',
        SavedItemType.institute => '/institutes/$id',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listings = ref.watch(savedListingsProvider(type));
    final noun = type == SavedItemType.course ? 'courses' : 'institutes';
    return listings.when(
      loading: () => const ListSkeleton(),
      error: (e, _) => ErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(savedListingsProvider(type)),
      ),
      data: (items) {
        if (items.isEmpty) {
          return EmptyState(
            icon: Icons.favorite_border_rounded,
            title: 'No saved $noun yet',
            message: 'Tap the heart on any ${noun.substring(0, noun.length - 1)} to keep it here.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(savedItemIdsProvider),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final item = items[i];
              return Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  onTap: () => context.push(_route(item.id)),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: item.imageUrl.isEmpty
                          ? ColoredBox(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              child: Icon(
                                type == SavedItemType.course
                                    ? Icons.menu_book_rounded
                                    : Icons.school_rounded,
                              ),
                            )
                          : AppNetworkImage(
                              url: item.imageUrl,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  title: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: item.subtitle.isEmpty ? null : Text(item.subtitle),
                  trailing: SaveListingButton(type: type, id: item.id),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
