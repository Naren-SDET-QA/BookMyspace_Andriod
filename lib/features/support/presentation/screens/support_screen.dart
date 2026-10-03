import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_navigation_controls.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../modules/presentation/module_providers.dart';
import '../../domain/help_faq.dart';
import '../../domain/support_ticket.dart';
import '../support_providers.dart';
import '../widgets/contextual_help_button.dart';
import '../widgets/help_assistant_sheet.dart';

class SupportTicketsScreen extends ConsumerWidget {
  const SupportTicketsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final enabled = ref.watch(moduleEnabledProvider('support'));
    final tickets = ref.watch(myTicketsProvider);
    final contact = ref.watch(supportContactProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const AppNavigationControls(),
        leadingWidth: AppNavigationControls.kLeadingWidth,
        title: Text(l10n.support),
        actions: const [ContextualHelpButton(route: AppRoutes.support)],
      ),
      body: !enabled
          ? const EmptyState(
              icon: Icons.support_agent_rounded,
              title: 'Support is unavailable',
              message:
                  'This optional module is currently disabled by the administrator.',
            )
          : ListView(
              key: const Key('support-hub-list'),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                _AssistantCard(
                  onOpen: () => showHelpAssistantSheet(
                    context,
                    onAction: (route) => _openRoute(context, ref, route),
                  ),
                ),
                if (!contact.isEmpty) ...[
                  const SizedBox(height: 12),
                  _ContactCard(contact: contact),
                ],
                const SizedBox(height: 20),
                const _SectionTitle('Frequently asked questions'),
                const SizedBox(height: 6),
                for (final faq in HelpFaqCatalog.answers)
                  _FaqTile(
                    faq: faq,
                    onAction: (route) => _openRoute(context, ref, route),
                  ),
                const SizedBox(height: 20),
                const _SectionTitle('My tickets'),
                const SizedBox(height: 6),
                tickets.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => ErrorView(
                    message: e.toString(),
                    onRetry: () => ref.invalidate(myTicketsProvider),
                  ),
                  data: (items) => items.isEmpty
                      ? EmptyState(
                          icon: Icons.headset_mic_rounded,
                          title: l10n.noSupportTickets,
                          message: l10n.ticketCreated,
                        )
                      : Column(
                          children: [
                            for (final ticket in items)
                              _TicketTile(ticket: ticket),
                          ],
                        ),
                ),
              ],
            ),
      floatingActionButton: enabled
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateDialog(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.newTicket),
            )
          : null,
    );
  }

  static const _shellTabs = {
    AppRoutes.home,
    AppRoutes.bookings,
    AppRoutes.saved,
    AppRoutes.profile,
  };

  void _openRoute(BuildContext context, WidgetRef ref, String route) {
    if (!context.mounted) return;
    if (route == AppRoutes.support) {
      _showCreateDialog(context, ref);
    } else if (_shellTabs.contains(route)) {
      context.go(route);
    } else {
      context.push(route);
    }
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final subjectController = TextEditingController();
    final descriptionController = TextEditingController();
    var category = 'general';
    var priority = TicketPriority.medium;

    showDialog<AlertDialog>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.newTicket),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: subjectController,
                  decoration: const InputDecoration(labelText: 'Subject'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  items: ['general', 'booking', 'payment', 'venue', 'other']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => category = v ?? 'general'),
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<TicketPriority>(
                  initialValue: priority,
                  items: TicketPriority.values
                      .map(
                        (p) => DropdownMenuItem(value: p, child: Text(p.name)),
                      )
                      .toList(),
                  onChanged: (v) =>
                      setState(() => priority = v ?? TicketPriority.medium),
                  decoration: const InputDecoration(labelText: 'Priority'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () async {
                if (subjectController.text.trim().isEmpty) return;
                final ticketParams = (
                  subject: subjectController.text.trim(),
                  description: descriptionController.text.trim(),
                  category: category,
                  priority: priority,
                );
                await ref.read(createTicketProvider(ticketParams).future);
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketTile extends ConsumerWidget {
  const _TicketTile({required this.ticket});

  final SupportTicket ticket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ticket.subject,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: ticket.isResolved
                        ? AppTheme.success.withValues(alpha: 0.12)
                        : AppTheme.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    ticket.isResolved ? 'Resolved' : ticket.status.dbValue,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: ticket.isResolved
                          ? AppTheme.success
                          : AppTheme.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              ticket.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '${l10n.priority}: ${ticket.priority.name}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  ticket.category,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (ticket.adminReply != null) ...[
              const SizedBox(height: 8),
              Text(
                ticket.adminReply!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.violet,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _AssistantCard extends StatelessWidget {
  const _AssistantCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.smart_toy_outlined, color: scheme.onPrimaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Help assistant',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  Text(
                    'Instant answers on refunds, payments, passes and more.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: const Key('support-open-assistant'),
              onPressed: onOpen,
              child: const Text('Chat'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.contact});

  final SupportContact contact;

  Future<void> _launch(BuildContext context, Uri uri) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await launchUrl(uri);
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open that app')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Talk to us',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                if (contact.hasPhone)
                  FilledButton.icon(
                    key: const Key('support-call'),
                    onPressed: () => _launch(
                      context,
                      Uri(scheme: 'tel', path: contact.phone.trim()),
                    ),
                    icon: const Icon(Icons.phone_rounded, size: 18),
                    label: const Text('Call support'),
                  ),
                if (contact.hasEmail)
                  OutlinedButton.icon(
                    key: const Key('support-email'),
                    onPressed: () => _launch(
                      context,
                      Uri(
                        scheme: 'mailto',
                        path: contact.email.trim(),
                        query: 'subject=Help%20request',
                      ),
                    ),
                    icon: const Icon(Icons.email_outlined, size: 18),
                    label: const Text('Email us'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.faq, required this.onAction});

  final HelpAnswer faq;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: Key('faq-${faq.topic.name}'),
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(
          faq.question,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            faq.answer,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (faq.hasAction)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => onAction(faq.actionRoute!),
                child: Text(faq.actionLabel!),
              ),
            ),
        ],
      ),
    );
  }
}
