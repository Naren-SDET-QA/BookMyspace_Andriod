import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/filter_checkbox_tile.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../modules/presentation/module_providers.dart';
import '../../domain/event.dart';
import '../../domain/event_discovery_query.dart';
import '../event_providers.dart';
import '../widgets/event_card.dart';

/// Upcoming events with local search and category/price filters.
class EventsListScreen extends ConsumerStatefulWidget {
  const EventsListScreen({super.key});

  @override
  ConsumerState<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends ConsumerState<EventsListScreen> {
  final _query = TextEditingController();
  EventCategory? _category;
  EventPriceFilter _price = EventPriceFilter.all;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final enabled = ref.watch(moduleEnabledProvider('events'));
    final events = ref.watch(upcomingEventsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.upcomingEvents)),
      body: !enabled
          ? const EmptyState(
              icon: Icons.event_busy_rounded,
              title: 'Events are unavailable',
              message:
                  'This optional module is currently disabled by the administrator.',
            )
          : events.when(
              loading: () => ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 4,
                itemBuilder: (context, i) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: SkeletonBox(height: 220, radius: 16),
                ),
              ),
              error: (e, _) => ErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(upcomingEventsProvider),
              ),
              data: (items) {
                final visible = EventDiscoveryQuery(
                  query: _query.text,
                  category: _category,
                  price: _price,
                ).apply(items);
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: TextField(
                        controller: _query,
                        decoration: InputDecoration(
                          hintText: l10n.searchEvents,
                          prefixIcon: const Icon(Icons.search),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    ExpansionTile(
                      title: const Text('Event category'),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Column(
                            children: [
                              FilterCheckboxTile(
                                label: l10n.allEvents,
                                value: _category == null,
                                onChanged: (selected) {
                                  if (selected) {
                                    setState(() => _category = null);
                                  }
                                },
                              ),
                              for (final category in EventCategory.values)
                                FilterCheckboxTile(
                                  label: category.name,
                                  value: _category == category,
                                  onChanged: (selected) {
                                    if (selected) {
                                      setState(() => _category = category);
                                    } else if (_category == category) {
                                      setState(() => _category = null);
                                    }
                                  },
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    ExpansionTile(
                      title: const Text('Price'),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Column(
                            children: [
                              for (final filter in EventPriceFilter.values)
                                FilterCheckboxTile(
                                  label: _priceLabel(filter, l10n),
                                  value: _price == filter,
                                  onChanged: (selected) {
                                    if (selected) {
                                      setState(() => _price = filter);
                                    }
                                  },
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: items.isEmpty
                          ? EmptyState(
                              icon: Icons.event_available_rounded,
                              title: l10n.noUpcomingEvents,
                              message: l10n.noUpcomingEventsMessage,
                            )
                          : visible.isEmpty
                          ? EmptyState(
                              icon: Icons.filter_alt_off_outlined,
                              title: l10n.noResults,
                              message: l10n.noResultsMessage,
                            )
                          : RefreshIndicator(
                              onRefresh: () async {
                                ref.invalidate(upcomingEventsProvider);
                                await ref.read(upcomingEventsProvider.future);
                              },
                              child: ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(16),
                                itemCount: visible.length,
                                itemBuilder: (context, i) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: EventCard(event: visible[i]),
                                ),
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  String _priceLabel(EventPriceFilter filter, AppLocalizations l10n) {
    return switch (filter) {
      EventPriceFilter.all => l10n.allEvents,
      EventPriceFilter.free => l10n.freeEvent,
      EventPriceFilter.paid => l10n.paidEvent,
    };
  }
}
