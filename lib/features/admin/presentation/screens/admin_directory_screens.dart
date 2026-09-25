import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../courses/presentation/widgets/course_card.dart';
import '../../../events/presentation/widgets/event_card.dart';
import '../admin_providers.dart';

class AdminUsersScreen extends ConsumerWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(adminUsersProvider);
    return _AdminListScaffold(
      title: 'Users',
      onRetry: () => ref.invalidate(adminUsersProvider),
      async: users,
      emptyTitle: 'No user profiles',
      emptyMessage: 'No profiles are visible to this administrator role.',
      itemBuilder: (context, index, items) {
        final user = items[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(user.displayName),
            subtitle: Text(
              [
                if (user.email.isNotEmpty) user.email,
                if (user.roles.isNotEmpty) user.roles.join(', '),
              ].join('\n'),
            ),
            isThreeLine: user.roles.isNotEmpty && user.email.isNotEmpty,
          ),
        );
      },
    );
  }
}

class AdminOwnersScreen extends ConsumerWidget {
  const AdminOwnersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owners = ref.watch(adminOwnersProvider);
    return _AdminListScaffold(
      title: 'Owners',
      onRetry: () => ref.invalidate(adminOwnersProvider),
      async: owners,
      emptyTitle: 'No owner organizations',
      emptyMessage: 'No organizations are visible to this administrator role.',
      itemBuilder: (context, index, items) {
        final owner = items[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(owner.name),
            subtitle: Text(
              [
                owner.orgType,
                if (owner.city.isNotEmpty) owner.city,
                'Identity: ${owner.identityVerification}',
                'Business: ${owner.businessVerification}',
              ].where((part) => part.trim().isNotEmpty).join(' • '),
            ),
            trailing: Text(owner.isActive ? 'Active' : 'Inactive'),
          ),
        );
      },
    );
  }
}

class AdminVenuesScreen extends ConsumerWidget {
  const AdminVenuesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venues = ref.watch(adminVenuesProvider);
    return _AdminListScaffold(
      title: 'Venues',
      onRetry: () => ref.invalidate(adminVenuesProvider),
      async: venues,
      emptyTitle: 'No venues',
      emptyMessage:
          'Only active, non-deleted venues are readable under current RLS.',
      itemBuilder: (context, index, items) {
        final venue = items[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(venue.name),
            subtitle: Text(
              [
                if (venue.city.isNotEmpty) venue.city,
                if (venue.ratingCount > 0)
                  '${venue.avgRating.toStringAsFixed(1)} (${venue.ratingCount})',
              ].join(' • '),
            ),
            onTap: () => context.push(
              AppRoutes.venueDetails.replaceAll(':id', venue.id),
            ),
          ),
        );
      },
    );
  }
}

class AdminEventsScreen extends ConsumerWidget {
  const AdminEventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(adminPublishedEventsProvider);
    return _AdminListScaffold(
      title: 'Published events',
      onRetry: () => ref.invalidate(adminPublishedEventsProvider),
      async: events,
      emptyTitle: 'No published events',
      emptyMessage: 'Unpublished events are not readable by this role.',
      itemBuilder: (context, index, items) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: EventCard(event: items[index]),
        );
      },
    );
  }
}

class AdminCoursesScreen extends ConsumerWidget {
  const AdminCoursesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses = ref.watch(adminPublishedCoursesProvider);
    return _AdminListScaffold(
      title: 'Published courses',
      onRetry: () => ref.invalidate(adminPublishedCoursesProvider),
      async: courses,
      emptyTitle: 'No published courses',
      emptyMessage: 'Unpublished courses are not readable by this role.',
      itemBuilder: (context, index, items) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: CourseCard(course: items[index]),
        );
      },
    );
  }
}

class AdminSupportScreen extends ConsumerWidget {
  const AdminSupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickets = ref.watch(adminSupportTicketsProvider);
    return _AdminListScaffold(
      title: 'Support tickets',
      onRetry: () => ref.invalidate(adminSupportTicketsProvider),
      async: tickets,
      emptyTitle: 'No support tickets',
      emptyMessage: 'No tickets are visible to this administrator role.',
      itemBuilder: (context, index, items) {
        final ticket = items[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(ticket.subject),
            subtitle: Text(
              '${ticket.status.dbValue} • ${ticket.category}\n${ticket.description}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            isThreeLine: true,
            trailing: ticket.isResolved
                ? const Icon(Icons.check_circle_outline)
                : TextButton(
                    onPressed: () async {
                      try {
                        await ref.read(
                          resolveSupportTicketProvider(ticket.id).future,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Ticket marked resolved.'),
                            ),
                          );
                        }
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error.toString())),
                          );
                        }
                      }
                    },
                    child: const Text('Resolve'),
                  ),
          ),
        );
      },
    );
  }
}

class AdminRlsBlockedScreen extends StatelessWidget {
  const AdminRlsBlockedScreen({
    super.key,
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: EmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Not available under current access',
          message: message.isEmpty
              ? 'The deployed Row Level Security policies do not grant administrators a platform-wide list of this resource. No fake rows are shown.'
              : message,
        ),
      ),
    );
  }
}

class _AdminListScaffold<T> extends StatelessWidget {
  const _AdminListScaffold({
    required this.title,
    required this.async,
    required this.onRetry,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.itemBuilder,
  });

  final String title;
  final AsyncValue<List<T>> async;
  final VoidCallback onRetry;
  final String emptyTitle;
  final String emptyMessage;
  final Widget Function(BuildContext context, int index, List<T> items)
      itemBuilder;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          message: error.toString(),
          onRetry: onRetry,
        ),
        data: (items) => items.isEmpty
            ? EmptyState(
                icon: Icons.inbox_outlined,
                title: emptyTitle,
                message: emptyMessage,
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) =>
                    itemBuilder(context, index, items),
              ),
      ),
    );
  }
}

class AdminBookingsBlockedScreen extends StatelessWidget {
  const AdminBookingsBlockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminRlsBlockedScreen(
      title: 'Bookings',
      message: '',
    );
  }
}

class AdminPaymentsBlockedScreen extends StatelessWidget {
  const AdminPaymentsBlockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminRlsBlockedScreen(
      title: 'Payments',
      message: '',
    );
  }
}
