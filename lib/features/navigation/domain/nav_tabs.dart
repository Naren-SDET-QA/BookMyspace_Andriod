import 'package:flutter/material.dart';

/// A destination the customer shell can show in its bottom bar.
///
/// [branch] is the index of the matching `StatefulShellBranch` in the router.
/// The route tree itself is fixed at build time: configuration decides which
/// branches are *reachable from the bar*, never how the tree is shaped. That
/// keeps navigation working for every route that is reached some other way —
/// a deep link, the assistant, or a "View bookings" button.
enum NavTab {
  home('home', 0, Icons.home_outlined, Icons.home_rounded),
  alerts(
    'alerts',
    1,
    Icons.notifications_outlined,
    Icons.notifications_rounded,
  ),
  search('search', 2, Icons.search_outlined, Icons.search_rounded),
  bookings(
    'bookings',
    3,
    Icons.receipt_long_outlined,
    Icons.receipt_long_rounded,
  ),
  courses('courses', 4, Icons.school_outlined, Icons.school_rounded),
  profile('profile', 5, Icons.person_outline_rounded, Icons.person_rounded),
  assistant(
    'assistant',
    6,
    Icons.auto_awesome_outlined,
    Icons.auto_awesome_rounded,
  );

  const NavTab(this.id, this.branch, this.icon, this.selectedIcon);

  final String id;
  final int branch;
  final IconData icon;
  final IconData selectedIcon;

  static NavTab? fromId(Object? id) {
    if (id is! String) return null;
    for (final value in values) {
      if (value.id == id) return value;
    }
    return null;
  }
}

/// Admin-controlled state for one bar destination.
@immutable
class NavTabConfig {
  const NavTabConfig({
    required this.tab,
    this.enabled = true,
    this.order = 0,
    this.label = '',
  });

  final NavTab tab;
  final bool enabled;
  final int order;

  /// Admin override for the visible label. Empty means "use the localized name",
  /// which is what keeps the bar translated in every shipped language.
  final String label;

  NavTabConfig copyWith({bool? enabled, int? order, String? label}) {
    return NavTabConfig(
      tab: tab,
      enabled: enabled ?? this.enabled,
      order: order ?? this.order,
      label: label ?? this.label,
    );
  }

  factory NavTabConfig.fromJson(Map json, NavTab fallbackTab) {
    return NavTabConfig(
      tab: NavTab.fromId(json['tab']) ?? fallbackTab,
      enabled: json['enabled'] != false,
      order: _int(json['order']) ?? 0,
      label: json['label'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'tab': tab.id,
        'enabled': enabled,
        'order': order,
        if (label.isNotEmpty) 'label': label,
      };
}

/// The complete bottom-bar composition.
@immutable
class NavTabsConfig {
  const NavTabsConfig(this.tabs);

  final List<NavTabConfig> tabs;

  /// Every destination in admin order, whether enabled or not.
  List<NavTabConfig> get ordered {
    final list = [...tabs]
      ..sort((a, b) {
        final byOrder = a.order.compareTo(b.order);
        // Tie-break on declaration order so a duplicated `order` still yields a
        // stable bar instead of one that shuffles between rebuilds.
        return byOrder != 0 ? byOrder : a.tab.index.compareTo(b.tab.index);
      });
    return list;
  }

  /// Destinations the customer should actually see, in admin order.
  List<NavTabConfig> get visible =>
      ordered.where((entry) => entry.enabled).toList();

  /// Branch index for each bar position, i.e. bar position -> `goBranch` index.
  List<int> get branchOrder => [for (final entry in visible) entry.tab.branch];

  NavTabConfig? configFor(NavTab tab) {
    for (final entry in tabs) {
      if (entry.tab == tab) return entry;
    }
    return null;
  }

  NavTabsConfig copyWithTab(NavTabConfig updated) {
    final next = <NavTabConfig>[];
    var replaced = false;
    for (final entry in tabs) {
      if (entry.tab == updated.tab) {
        next.add(updated);
        replaced = true;
      } else {
        next.add(entry);
      }
    }
    if (!replaced) next.add(updated);
    return NavTabsConfig(next);
  }

  /// Shipped default: the existing six-tab bar, unchanged.
  ///
  /// The assistant tab ships **off**. Adding a seventh destination to a phone
  /// bar would crowd the six that already fit, so an admin opts in from the
  /// console — and can retire a tab they do not need to make room.
  static const NavTabsConfig defaults = NavTabsConfig([
    NavTabConfig(tab: NavTab.home, order: 10),
    NavTabConfig(tab: NavTab.alerts, order: 20),
    NavTabConfig(tab: NavTab.search, order: 30),
    NavTabConfig(tab: NavTab.bookings, order: 40),
    NavTabConfig(tab: NavTab.courses, order: 50),
    NavTabConfig(tab: NavTab.profile, order: 60),
    NavTabConfig(tab: NavTab.assistant, order: 70, enabled: false),
  ]);

  factory NavTabsConfig.fromJson(Object? json) {
    if (json is! Map) return defaults;
    final rawTabs = json['tabs'];
    if (rawTabs is! List) return defaults;

    final parsed = <NavTabConfig>[];
    for (final entry in rawTabs) {
      if (entry is! Map) continue;
      final tab = NavTab.fromId(entry['tab']);
      if (tab == null) continue;
      parsed.add(NavTabConfig.fromJson(entry, tab));
    }
    if (parsed.isEmpty) return defaults;

    // A destination the admin never mentioned keeps its shipped default, so
    // adding a new tab type never silently disappears from the bar.
    for (final fallback in defaults.tabs) {
      if (!parsed.any((entry) => entry.tab == fallback.tab)) {
        parsed.add(fallback);
      }
    }
    return NavTabsConfig(parsed);
  }

  Map<String, dynamic> toJson() => {
        'tabs': [for (final entry in tabs) entry.toJson()],
      };
}

int? _int(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
