import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/router/search_route.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../search/presentation/widgets/voice_search_bottom_sheet.dart';
import '../../domain/ai_booking_intent.dart';

/// One exchange: what the customer said, and what the assistant made of it.
class _AiTurn {
  const _AiTurn({required this.userText, required this.intent});

  final String userText;
  final AiBookingIntent intent;
}

/// Conversational front door to booking.
///
/// The customer types or speaks in plain language; the assistant answers with
/// the filters it understood and hands off to the real Search or Bookings
/// screen. It never books anything by itself — the confirm step stays with the
/// customer, on screens guarded by the backend's own role and RLS rules.
class AiBookingSheet extends StatefulWidget {
  const AiBookingSheet({super.key, this.initialText});

  /// Optional opening question, so a Home card can deep-link into an answer.
  final String? initialText;

  static Future<void> show(BuildContext context, {String? initialText}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AiBookingSheet(initialText: initialText),
    );
  }

  @override
  State<AiBookingSheet> createState() => _AiBookingSheetState();
}

class _AiBookingSheetState extends State<AiBookingSheet> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _turns = <_AiTurn>[];

  @override
  void initState() {
    super.initState();
    final seed = widget.initialText?.trim();
    if (seed != null && seed.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _submit(seed);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _submit(String text) {
    final value = text.trim();
    if (value.isEmpty) return;
    final intent = AiBookingEngine.interpret(value);
    setState(() {
      _turns.add(_AiTurn(userText: value, intent: intent));
      _controller.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
  }

  void _scrollToEnd() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  /// Leaves the sheet, then navigates on the *router* we captured first — the
  /// sheet's own context is gone the moment it pops.
  void _leaveThenGo(String location) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.go(location);
  }

  Future<void> _startVoice() async {
    await VoiceSearchBottomSheet.show(
      context,
      onFilterApplied: (result) {
        if (!mounted) return;
        _submit(result.rawSpokenText);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.78,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        padding: EdgeInsets.only(
          top: 12,
          left: 18,
          right: 18,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dragHandle(theme),
            const SizedBox(height: 12),
            _header(l10n, theme),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                controller: _scroll,
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 4),
                itemCount: _turns.isEmpty ? 1 : _turns.length,
                itemBuilder: (context, index) {
                  if (_turns.isEmpty) {
                    return _assistantBubble(
                      intent: AiBookingEngine.interpret('hello'),
                      l10n: l10n,
                      theme: theme,
                      isDark: isDark,
                      showQuick: true,
                    );
                  }
                  final turn = _turns[index];
                  final isLast = index == _turns.length - 1;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _userBubble(turn.userText, theme),
                      const SizedBox(height: 10),
                      _assistantBubble(
                        intent: turn.intent,
                        l10n: l10n,
                        theme: theme,
                        isDark: isDark,
                        showQuick: isLast,
                      ),
                      const SizedBox(height: 14),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            _composer(l10n, theme, isDark),
            const SizedBox(height: 8),
            _deviceNote(l10n, theme),
          ],
        ),
      ),
    );
  }

  // --- Chrome ---------------------------------------------------------------

  Widget _dragHandle(ThemeData theme) {
    return Container(
      width: 44,
      height: 4,
      decoration: BoxDecoration(
        color: theme.colorScheme.outlineVariant,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _header(AppLocalizations l10n, ThemeData theme) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppTheme.brandGradient,
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.aiAssistantTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                l10n.aiAssistantSubtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: l10n.close,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _deviceNote(AppLocalizations l10n, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.lock_outline_rounded,
          size: 13,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            l10n.aiOnDeviceNote,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  // --- Bubbles --------------------------------------------------------------

  Widget _userBubble(String text, ThemeData theme) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: AppTheme.brandGradient,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _assistantBubble({
    required AiBookingIntent intent,
    required AppLocalizations l10n,
    required ThemeData theme,
    required bool isDark,
    required bool showQuick,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.brand.withValues(alpha: 0.14),
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            size: 13,
            color: AppTheme.brand,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.45),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.aiText(intent.replyKey),
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
                ),
                if (intent.chips.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final chip in intent.chips)
                        _chip(chip, l10n, theme),
                    ],
                  ),
                ],
                if (intent.offersResults || intent.offersBookings) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => intent.offersResults
                          ? _leaveThenGo(
                              SearchRouteParams.locationFor(intent.query),
                            )
                          : _leaveThenGo(AppRoutes.bookings),
                      icon: Icon(
                        intent.offersResults
                            ? Icons.travel_explore_rounded
                            : Icons.receipt_long_rounded,
                        size: 18,
                      ),
                      label: Text(
                        intent.offersResults
                            ? l10n.aiShowResults
                            : l10n.aiOpenBookings,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        backgroundColor: AppTheme.brand,
                      ),
                    ),
                  ),
                ],
                if (showQuick && intent.quickKeys.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    l10n.aiQuickTitle,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final key in intent.quickKeys)
                        _quickChip(key, l10n, theme),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _chip(AiIntentChip chip, AppLocalizations l10n, ThemeData theme) {
    final value = chip.isLocalized
        ? l10n.aiText(chip.valueKey)
        : chip.rawValue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(chip.emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 5),
          Text(
            '${l10n.aiText(chip.slotKey)}: $value',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  /// Suggestions are *shown* in the active language but *submitted* in the
  /// English vocabulary the deterministic parser understands.
  Widget _quickChip(String key, AppLocalizations l10n, ThemeData theme) {
    return ActionChip(
      label: Text(
        l10n.aiText(key),
        style: theme.textTheme.labelSmall?.copyWith(fontSize: 11),
      ),
      onPressed: () => _submit(AppLocalizations.english(key)),
      backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.9),
      side: BorderSide(
        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
      ),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  // --- Composer -------------------------------------------------------------

  Widget _composer(AppLocalizations l10n, ThemeData theme, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            textInputAction: TextInputAction.send,
            minLines: 1,
            maxLines: 3,
            onSubmitted: _submit,
            style: const TextStyle(fontSize: 13.5),
            decoration: InputDecoration(
              hintText: l10n.aiInputHint,
              hintStyle: TextStyle(
                fontSize: 12.5,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              filled: true,
              fillColor: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        IconButton.filledTonal(
          onPressed: _startVoice,
          tooltip: l10n.search,
          icon: const Icon(Icons.mic_rounded, size: 20),
        ),
        const SizedBox(width: 6),
        IconButton.filled(
          onPressed: () => _submit(_controller.text),
          tooltip: l10n.aiSend,
          style: IconButton.styleFrom(backgroundColor: AppTheme.brand),
          icon: const Icon(Icons.arrow_upward_rounded, size: 20),
        ),
      ],
    );
  }
}
