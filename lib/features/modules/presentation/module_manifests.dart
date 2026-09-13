import '../domain/feature_flag.dart';

class ModuleManifest {
  const ModuleManifest({
    required this.id,
    required this.name,
    required this.description,
    this.defaultEnabled = true,
    this.defaultConfig = const {},
    this.platforms = const ['ios', 'android', 'web'],
  });

  final String id;
  final String name;
  final String description;
  final bool defaultEnabled;
  final Map<String, dynamic> defaultConfig;
  final List<String> platforms;

  FeatureFlag fallback() => FeatureFlag(
        key: id,
        enabled: defaultEnabled,
        platforms: platforms,
        config: defaultConfig,
      );
}

/// Only optional, already implemented modules are configurable here. Core
/// booking, payments, auth, search, venue management, notifications and the
/// six-tab customer shell are intentionally absent from this list.
const optionalModuleManifests = <ModuleManifest>[
  ModuleManifest(
    id: 'offers',
    name: 'Offers and coupons',
    description: 'Customer offers already backed by the coupons table.',
  ),
  ModuleManifest(
    id: 'events',
    name: 'Events',
    description: 'Published event discovery and detail screens.',
  ),
  ModuleManifest(
    id: 'courses',
    name: 'Courses',
    description: 'Published course discovery and detail screens.',
  ),
  ModuleManifest(
    id: 'reviews',
    name: 'Reviews',
    description: 'Venue reviews and ratings.',
  ),
  ModuleManifest(
    id: 'favorites',
    name: 'Favorites',
    description: 'Saved venues for signed-in customers.',
  ),
  ModuleManifest(
    id: 'support',
    name: 'Support',
    description: 'Customer support tickets and replies.',
  ),
  ModuleManifest(
    id: 'analytics',
    name: 'Analytics',
    description: 'Authorized product analytics collection and reports.',
    defaultConfig: {'max_items': 100},
  ),
  ModuleManifest(
    id: 'integrations',
    name: 'External integrations',
    description: 'Configured provider health and connector surfaces.',
  ),
  ModuleManifest(
    id: 'referrals',
    name: 'Referrals and rewards',
    description: 'Enable only when the referral backend is configured.',
    defaultEnabled: false,
    defaultConfig: {'reward_amount': 0, 'expiry_days': 30},
  ),
  ModuleManifest(
    id: 'home_appearance',
    name: 'Home layout and theming',
    description:
        'Customer Home composition: which blocks appear, their order, titles, '
        'artwork, background colours and borders.',
    // An empty config resolves to the shipped HomeAppearance.defaults.
  ),
];

ModuleManifest? moduleManifestFor(String id) {
  for (final manifest in optionalModuleManifests) {
    if (manifest.id == id) return manifest;
  }
  return null;
}
