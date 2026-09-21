import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../modules/presentation/module_providers.dart';
import '../../domain/course.dart';
import '../course_providers.dart';
import '../widgets/course_card.dart';
import '../widgets/external_link.dart';

/// Institute profile: logo, type, about, location, contact, timings and the
/// published courses it offers.
class InstituteDetailScreen extends ConsumerWidget {
  const InstituteDetailScreen({required this.instituteId, super.key});

  final String instituteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final enabled = ref.watch(moduleEnabledProvider('courses'));
    final instituteAsync = ref.watch(instituteDetailProvider(instituteId));

    return Scaffold(
      body: !enabled
          ? SafeArea(
              child: EmptyState(
                icon: Icons.school_outlined,
                title: l10n.educationUnavailable,
                message: l10n.educationUnavailableMessage,
              ),
            )
          : instituteAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorView(
                message: e.toString(),
                onRetry: () =>
                    ref.invalidate(instituteDetailProvider(instituteId)),
              ),
              data: (institute) => _InstituteBody(institute: institute),
            ),
    );
  }
}

class _InstituteBody extends ConsumerWidget {
  const _InstituteBody({required this.institute});

  final Institute institute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final coursesAsync = ref.watch(instituteCoursesProvider(institute.id));

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 200,
          flexibleSpace: FlexibleSpaceBar(
            background: AppNetworkImage(
              url: institute.images.isNotEmpty
                  ? institute.images.first
                  : institute.logoImage,
              fit: BoxFit.cover,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        institute.name,
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (institute.isVerified)
                      const Icon(Icons.verified_rounded,
                          color: AppTheme.violet),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoChip(
                      icon: Icons.account_balance_rounded,
                      label: institute.type.label,
                    ),
                    _InfoChip(
                      icon: Icons.wifi_tethering_rounded,
                      label: _modeLabel(l10n, institute.mode),
                    ),
                    if (institute.city.isNotEmpty)
                      _InfoChip(
                        icon: Icons.location_on_rounded,
                        label: institute.city,
                      ),
                  ],
                ),
                if (institute.description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(l10n.aboutInstitute, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    institute.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (institute.modules.show(
                  key: 'location',
                  hasData: institute.hasLocation ||
                      institute.branches.any((b) => b.hasAddress),
                )) ...[
                  const SizedBox(height: 16),
                  Text(l10n.location, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    [institute.address, institute.city]
                        .where((p) => p.isNotEmpty)
                        .join(', '),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (institute.timingsText.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(l10n.timings, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    institute.timingsText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (institute.modules.enabled('faculty'))
                  _InstituteFaculty(instituteId: institute.id),
                if (institute.hasContact || institute.website.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(l10n.contactInstitute,
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _ContactActions(institute: institute),
                ],
                const SizedBox(height: 20),
                Text(l10n.coursesByInstitute,
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
        coursesAsync.when(
          loading: () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (e, _) => SliverToBoxAdapter(
            child: ErrorView(
              message: e.toString(),
              onRetry: () =>
                  ref.invalidate(instituteCoursesProvider(institute.id)),
            ),
          ),
          data: (courses) => courses.isEmpty
              ? SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: EmptyState(
                      icon: Icons.school_outlined,
                      title: l10n.noCourses,
                      message: l10n.noCoursesMessage,
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList.separated(
                    itemCount: courses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (_, i) => CourseCard(course: courses[i]),
                  ),
                ),
        ),
      ],
    );
  }

  static String _modeLabel(AppLocalizations l10n, CourseMode mode) =>
      switch (mode) {
        CourseMode.online => l10n.modeOnline,
        CourseMode.offline => l10n.modeOffline,
        CourseMode.hybrid => l10n.modeHybrid,
      };
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18, color: AppTheme.violet),
      label: Text(label),
    );
  }
}

class _InstituteFaculty extends ConsumerWidget {
  const _InstituteFaculty({required this.instituteId});

  final String instituteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses =
        ref.watch(instituteCoursesProvider(instituteId)).valueOrNull;
    if (courses == null) return const SizedBox.shrink();
    final faculty = [
      for (final course in courses) ...course.faculty,
    ].where((item) => item.name.isNotEmpty).toList();
    if (faculty.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Faculty', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final item in faculty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                [
                  item.name,
                  if (item.role.isNotEmpty) item.role,
                  if (item.qualification.isNotEmpty) item.qualification,
                ].join(' · '),
              ),
            ),
        ],
      ),
    );
  }
}

class _ContactActions extends StatelessWidget {
  const _ContactActions({required this.institute});

  final Institute institute;

  @override
  Widget build(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    final buttons = <Widget>[];

    if (institute.phone.isNotEmpty) {
      buttons.add(OutlinedButton.icon(
        icon: const Icon(Icons.phone_rounded, size: 18),
        label: Text(institute.phone),
        onPressed: () => _guard(openContactLink(institute.phone), messenger),
      ));
    }
    if (institute.whatsapp.isNotEmpty) {
      buttons.add(OutlinedButton.icon(
        icon: const Icon(Icons.chat_rounded, size: 18),
        label: const Text('WhatsApp'),
        onPressed: () => _guard(openWhatsApp(institute.whatsapp), messenger),
      ));
    }
    if (institute.email.isNotEmpty) {
      buttons.add(OutlinedButton.icon(
        icon: const Icon(Icons.email_rounded, size: 18),
        label: Text(institute.email),
        onPressed: () =>
            _guard(openContactLink('mailto:${institute.email}'), messenger),
      ));
    }
    if (institute.website.isNotEmpty && isSafeExternalUrl(institute.website)) {
      buttons.add(OutlinedButton.icon(
        icon: const Icon(Icons.language_rounded, size: 18),
        label: const Text('Website'),
        onPressed: () => _guard(openMediaUrl(institute.website), messenger),
      ));
    }

    return Wrap(spacing: 8, runSpacing: 8, children: buttons);
  }

  Future<void> _guard(
    Future<bool> action,
    ScaffoldMessengerState messenger,
  ) async {
    final ok = await action;
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open that link.')),
      );
    }
  }
}
