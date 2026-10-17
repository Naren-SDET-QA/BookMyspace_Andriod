import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/marketplace_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/skeleton.dart';
import '../../home/presentation/discovery_location.dart';
import '../../home/presentation/widgets/location_picker_sheet.dart';
import '../domain/marketplace_catalog.dart';
import 'marketplace_providers.dart';

class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({super.key});
  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  String _text = '';
  MarketplaceCategory _category = MarketplaceCategory.all;
  MarketplaceSort _sort = MarketplaceSort.relevance;
  double? _maxPrice;
  DateTimeRange? _dates;
  int _offset = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _searchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted)
        setState(() {
          _text = value.trim();
          _offset = 0;
        });
    });
  }

  void _reset() {
    _debounce?.cancel();
    _search.clear();
    setState(() {
      _text = '';
      _category = MarketplaceCategory.all;
      _sort = MarketplaceSort.relevance;
      _maxPrice = null;
      _dates = null;
      _offset = 0;
    });
  }

  Future<void> _pickDates() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final dates = await showDateRangePicker(
      context: context,
      firstDate: today,
      lastDate: DateTime(today.year + 2),
      initialDateRange: _dates,
    );
    if (mounted && dates != null)
      setState(() {
        _dates = dates;
        _offset = 0;
      });
  }

  void _page(int delta) {
    setState(() => _offset += delta);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final location = ref.watch(discoveryLocationProvider);
    ref.listen(discoveryLocationProvider, (previous, next) {
      if (previous?.city != next.city && _offset != 0)
        setState(() => _offset = 0);
    });
    final query = MarketplaceQuery(
      text: _text,
      city: location.city,
      category: _category,
      sort: _sort,
      maxPrice: _maxPrice,
      offset: _offset,
      from: _dates?.start,
      until: _dates == null
          ? null
          : DateTime(_dates!.end.year, _dates!.end.month, _dates!.end.day + 1),
    );
    final results = ref.watch(marketplaceResultsProvider(query));
    final currency = NumberFormat.simpleCurrency(
      locale: l10n.locale.toString(),
      name: 'INR',
      decimalDigits: 0,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.marketplaceText('marketplace'))),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(marketplaceResultsProvider(query));
          await ref.read(marketplaceResultsProvider(query).future);
        },
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.local_activity_outlined,
                                color: theme.colorScheme.onPrimaryContainer,
                                size: 36,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l10n.marketplaceText('marketplaceIntro'),
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                l10n.marketplaceText('marketplaceSubtitle'),
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            icon: const Icon(Icons.location_on_outlined),
                            onPressed: () async {
                              await showModalBottomSheet<void>(
                                context: context,
                                isScrollControlled: true,
                                useSafeArea: true,
                                builder: (_) => const LocationPickerSheet(),
                              );
                            },
                            label: Text(
                              location.hasCity
                                  ? location.city!
                                  : l10n.marketplaceText('marketplaceLocation'),
                            ),
                          ),
                        ),
                        if (location.hasCity)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () => ref
                                  .read(discoveryLocationProvider.notifier)
                                  .setCity(null),
                              child: Text(
                                l10n.marketplaceText('marketplaceAllCities'),
                              ),
                            ),
                          ),
                        TextField(
                          key: const Key('marketplace-search'),
                          controller: _search,
                          maxLength: 200,
                          textInputAction: TextInputAction.search,
                          onChanged: _searchChanged,
                          decoration: InputDecoration(
                            labelText: l10n.marketplaceText(
                              'marketplaceSearch',
                            ),
                            prefixIcon: const Icon(Icons.search),
                            counterText: '',
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final category in MarketplaceCategory.values)
                              ChoiceChip(
                                key: ValueKey(
                                  'marketplace-category-${category.name}',
                                ),
                                label: Text(_categoryLabel(l10n, category)),
                                selected: _category == category,
                                onSelected: (_) => setState(() {
                                  _category = category;
                                  _offset = 0;
                                }),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 16,
                          runSpacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            DropdownMenu<MarketplaceSort>(
                              key: ValueKey('marketplace-sort-$_sort'),
                              initialSelection: _sort,
                              label: Text(
                                l10n.marketplaceText('marketplaceSort'),
                              ),
                              dropdownMenuEntries: [
                                for (final sort in MarketplaceSort.values)
                                  DropdownMenuEntry(
                                    value: sort,
                                    label: _sortLabel(l10n, sort),
                                  ),
                              ],
                              onSelected: (value) {
                                if (value != null)
                                  setState(() {
                                    _sort = value;
                                    _offset = 0;
                                  });
                              },
                            ),
                            DropdownMenu<double>(
                              key: ValueKey('marketplace-price-$_maxPrice'),
                              initialSelection: _maxPrice ?? -1,
                              label: Text(
                                l10n.marketplaceText('marketplacePrice'),
                              ),
                              dropdownMenuEntries: [
                                DropdownMenuEntry(
                                  value: -1,
                                  label: l10n.marketplaceText(
                                    'marketplaceAnyPrice',
                                  ),
                                ),
                                for (final price in [500.0, 1500.0, 3000.0])
                                  DropdownMenuEntry(
                                    value: price,
                                    label: l10n
                                        .marketplaceText('marketplaceUpTo')
                                        .replaceAll(
                                          '{price}',
                                          currency.format(price),
                                        ),
                                  ),
                              ],
                              onSelected: (value) => setState(() {
                                _maxPrice = value == -1 ? null : value;
                                _offset = 0;
                              }),
                            ),
                            OutlinedButton.icon(
                              onPressed: _pickDates,
                              icon: const Icon(Icons.date_range),
                              label: Text(
                                _dates == null
                                    ? l10n.marketplaceText('marketplaceDate')
                                    : '${DateFormat.MMMd(l10n.locale.toString()).format(_dates!.start)} – ${DateFormat.MMMd(l10n.locale.toString()).format(_dates!.end)}',
                              ),
                            ),
                            TextButton(
                              onPressed: _reset,
                              child: Text(
                                l10n.marketplaceText('marketplaceReset'),
                              ),
                            ),
                          ],
                        ),
                        if (_dates != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              l10n.marketplaceText('marketplaceDateHint'),
                            ),
                          ),
                        const SizedBox(height: 24),
                        Text(
                          l10n.marketplaceText('marketplaceResults'),
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        results.when(
                          loading: () => const Column(
                            children: [
                              SkeletonBox(height: 220, radius: 20),
                              SizedBox(height: 16),
                              SkeletonBox(height: 220, radius: 20),
                            ],
                          ),
                          error: (_, __) => _CatalogMessage(
                            icon: Icons.cloud_off_outlined,
                            title: l10n.marketplaceText('marketplaceError'),
                            action: l10n.marketplaceText('marketplaceRetry'),
                            onAction: () => ref.invalidate(
                              marketplaceResultsProvider(query),
                            ),
                          ),
                          data: (items) => Column(
                            children: [
                              if (items.isEmpty)
                                _CatalogMessage(
                                  icon: Icons.travel_explore,
                                  title: l10n.marketplaceText(
                                    'marketplaceEmpty',
                                  ),
                                  message: l10n.marketplaceText(
                                    'marketplaceEmptyMessage',
                                  ),
                                  action: l10n.marketplaceText(
                                    'marketplaceReset',
                                  ),
                                  onAction: _reset,
                                ),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final columns = math.max(
                                    1,
                                    (constraints.maxWidth / 300).floor(),
                                  );
                                  final width =
                                      (constraints.maxWidth -
                                          (columns - 1) * 16) /
                                      columns;
                                  return Wrap(
                                    spacing: 16,
                                    runSpacing: 16,
                                    children: [
                                      for (final item in items)
                                        SizedBox(
                                          width: width,
                                          child: _CatalogCard(item: item),
                                        ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 20),
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                children: [
                                  if (_offset > 0)
                                    OutlinedButton(
                                      onPressed: () => _page(-query.pageSize),
                                      child: Text(
                                        l10n.marketplaceText(
                                          'marketplacePrevious',
                                        ),
                                      ),
                                    ),
                                  if (items.length == query.pageSize &&
                                      _offset + query.pageSize <= 10000)
                                    FilledButton(
                                      onPressed: () => _page(query.pageSize),
                                      child: Text(
                                        l10n.marketplaceText('marketplaceNext'),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogMessage extends StatelessWidget {
  const _CatalogMessage({
    required this.icon,
    required this.title,
    this.message,
    required this.action,
    required this.onAction,
  });
  final IconData icon;
  final String title, action;
  final String? message;
  final VoidCallback onAction;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Column(
      children: [
        Icon(icon, size: 48),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (message != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(message!, textAlign: TextAlign.center),
          ),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onAction, child: Text(action)),
      ],
    ),
  );
}

class _CatalogCard extends StatelessWidget {
  const _CatalogCard({required this.item});
  final MarketplaceItem item;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final price = NumberFormat.simpleCurrency(
      locale: l10n.locale.toString(),
      name: item.currency,
      decimalDigits: 0,
    ).format(item.price);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        key: ValueKey('marketplace-item-${item.key}'),
        onTap: () => context.navigateSafely(item.location),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1.65,
              child: AppNetworkImage(url: item.imageUrl),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _categoryLabel(l10n, item.category),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (item.city.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(item.city),
                    ),
                  if (item.startsAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        DateFormat.yMMMd(
                          l10n.locale.toString(),
                        ).add_jm().format(item.startsAt!.toLocal()),
                      ),
                    ),
                  if (item.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        item.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (item.rating != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 18),
                          const SizedBox(width: 4),
                          Text(item.rating!.toStringAsFixed(1)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    item.price == 0
                        ? l10n.marketplaceText('marketplaceFree')
                        : l10n
                              .marketplaceText('marketplaceFrom')
                              .replaceAll('{price}', price),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.marketplaceText('marketplaceOpen'),
                    style: TextStyle(color: theme.colorScheme.primary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _categoryLabel(AppLocalizations l10n, MarketplaceCategory category) =>
    l10n.marketplaceText(switch (category) {
      MarketplaceCategory.all => 'marketplaceAll',
      MarketplaceCategory.events => 'marketplaceEvents',
      MarketplaceCategory.venues => 'marketplaceVenues',
      MarketplaceCategory.sports => 'marketplaceSports',
      MarketplaceCategory.restaurants => 'marketplaceRestaurants',
      MarketplaceCategory.experiences => 'marketplaceExperiences',
      MarketplaceCategory.courses => 'marketplaceCourses',
    });

String _sortLabel(AppLocalizations l10n, MarketplaceSort sort) =>
    l10n.marketplaceText(switch (sort) {
      MarketplaceSort.relevance => 'marketplaceRelevance',
      MarketplaceSort.priceLow => 'marketplacePriceLow',
      MarketplaceSort.priceHigh => 'marketplacePriceHigh',
      MarketplaceSort.rating => 'marketplaceRating',
      MarketplaceSort.soonest => 'marketplaceSoonest',
    });
