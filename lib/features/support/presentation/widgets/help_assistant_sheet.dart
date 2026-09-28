import 'package:flutter/material.dart';

import '../../domain/help_faq.dart';

/// Opens the keyword-matched FAQ help assistant. [onAction] receives the
/// route of the tapped action button after the sheet closes.
Future<void> showHelpAssistantSheet(
  BuildContext context, {
  required ValueChanged<String> onAction,
}) async {
  final route = await showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const HelpAssistantSheet(),
  );
  if (route != null) onAction(route);
}

class _ChatEntry {
  const _ChatEntry.user(this.text) : isBot = false, answer = null;
  const _ChatEntry.bot(this.text, {this.answer}) : isBot = true;

  final String text;
  final bool isBot;
  final HelpAnswer? answer;
}

class HelpAssistantSheet extends StatefulWidget {
  const HelpAssistantSheet({super.key});

  @override
  State<HelpAssistantSheet> createState() => _HelpAssistantSheetState();
}

class _HelpAssistantSheetState extends State<HelpAssistantSheet> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<_ChatEntry> _entries = [
    const _ChatEntry.bot(
      'Hi! Ask me about refunds, wallet & referrals, promo codes, QR passes, '
      'payments, PGs, listing your property or contacting support.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return;
    final match = HelpFaqCatalog.match(text);
    setState(() {
      _entries.add(_ChatEntry.user(text));
      _entries.add(
        match == null
            ? const _ChatEntry.bot(
                "Sorry, I don't have an answer for that yet. Try one of the "
                'topics below, or raise a support ticket.',
              )
            : _ChatEntry.bot(match.answer, answer: match),
      );
    });
    _controller.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final height = MediaQuery.sizeOf(context).height * 0.8;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.smart_toy_outlined, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Help assistant',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                key: const Key('help-assistant-messages'),
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                itemCount: _entries.length,
                itemBuilder: (context, i) => _Bubble(entry: _entries[i]),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: HelpFaqCatalog.suggestions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final label = HelpFaqCatalog.suggestions[i];
                  return ActionChip(
                    label: Text(label),
                    onPressed: () => _send(label),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('help-assistant-input'),
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _send,
                      decoration: const InputDecoration(
                        hintText: 'Type your question...',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('help-assistant-send'),
                    tooltip: 'Send',
                    icon: const Icon(Icons.send_rounded),
                    onPressed: () => _send(_controller.text),
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

class _Bubble extends StatelessWidget {
  const _Bubble({required this.entry});

  final _ChatEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final answer = entry.answer;
    return Align(
      alignment: entry.isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: entry.isBot
                ? scheme.surfaceContainerHighest
                : scheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (answer != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    answer.question,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              Text(
                entry.text,
                style: TextStyle(
                  color: entry.isBot
                      ? scheme.onSurface
                      : scheme.onPrimaryContainer,
                ),
              ),
              if (answer != null && answer.hasAction) ...[
                const SizedBox(height: 8),
                FilledButton.tonal(
                  key: Key('help-action-${answer.topic.name}'),
                  onPressed: () =>
                      Navigator.of(context).pop(answer.actionRoute),
                  child: Text(answer.actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
