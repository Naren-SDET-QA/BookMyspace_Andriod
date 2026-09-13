import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../ai_booking/presentation/widgets/ai_booking_sheet.dart';
import '../../domain/home_appearance.dart';

/// Compact, colourful entry point to the AI booking assistant.
///
/// Deliberately slim: it sits high on Home, so it advertises the assistant
/// without pushing the category matrix off the first screen. Admins theme it
/// through the same [HomeBlockStyle] every other Home block uses.
class HomeAiBookingCard extends StatefulWidget {
  const HomeAiBookingCard({
    super.key,
    this.title = '',
    this.subtitle = '',
    this.style = const HomeBlockStyle(),
  });

  /// Admin override. Falls back to the localized assistant name.
  final String title;

  /// Admin override. Falls back to the localized one-liner.
  final String subtitle;

  final HomeBlockStyle style;

  @override
  State<HomeAiBookingCard> createState() => _HomeAiBookingCardState();
}

class _HomeAiBookingCardState extends State<HomeAiBookingCard>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _drift;
  late final AnimationController _pulse;

  /// Shipped palette: the one place on Home that is intentionally multi-hued.
  static const List<Color> _defaultGradient = [
    Color(0xFF7C3AED),
    Color(0xFF2563EB),
    Color(0xFFDB2777),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _setRunning(true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setRunning(!MediaQuery.disableAnimationsOf(context));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _setRunning(state == AppLifecycleState.resumed && mounted);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _drift.dispose();
    _pulse.dispose();
    super.dispose();
  }

  /// Looping animation is skipped under `flutter test`, where an endless ticker
  /// would make `pumpAndSettle` never return. Reduced-motion is honoured too.
  bool get _isWidgetTest => WidgetsBinding.instance.runtimeType
      .toString()
      .contains('TestWidgetsFlutterBinding');

  void _setRunning(bool running) {
    final allowLoop = running && !_isWidgetTest;
    if (allowLoop) {
      if (!_drift.isAnimating) _drift.repeat();
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _drift.stop();
      _pulse.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final style = widget.style;
    final colors =
        style.backgroundColors.isEmpty ? _defaultGradient : style.backgroundColors;
    final radius = style.radius;

    return Semantics(
      button: true,
      label: l10n.aiAssistantTitle,
      child: InkWell(
        onTap: () => AiBookingSheet.show(context),
        borderRadius: BorderRadius.circular(radius),
        child: AnimatedBuilder(
          animation: Listenable.merge([_drift, _pulse]),
          builder: (context, _) {
            final shift = _drift.value * 2 - 1; // -1 .. 1
            final halo = 0.28 + (_pulse.value * 0.22);
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                border: style.borderColor != null
                    ? Border.all(
                        color: style.borderColor!,
                        width: style.borderWidth > 0 ? style.borderWidth : 1,
                      )
                    : null,
                boxShadow: style.glow
                    ? [
                        BoxShadow(
                          color: colors.first.withValues(alpha: halo),
                          blurRadius: 22,
                          spreadRadius: 1,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: colors.first.withValues(alpha: 0.24),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment(-1 + shift, -1),
                            end: Alignment(1 + shift, 1),
                            colors: colors,
                          ),
                        ),
                      ),
                    ),
                    // Moving sheen so the card reads as "live" without a GIF.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Align(
                          alignment: Alignment(-1.6 + (_drift.value * 3.2), 0),
                          child: Container(
                            width: 90,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0),
                                  Colors.white.withValues(alpha: 0.16),
                                  Colors.white.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      child: Row(
                        children: [
                          _sparkle(halo),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.title.isEmpty
                                      ? l10n.aiAssistantTitle
                                      : widget.title,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: style.titleColor ?? Colors.white,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.subtitle.isEmpty
                                      ? l10n.aiAssistantSubtitle
                                      : widget.subtitle,
                                  style: TextStyle(
                                    color: (style.titleColor ?? Colors.white)
                                        .withValues(alpha: 0.88),
                                    fontSize: 11.5,
                                    height: 1.25,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _sparkle(double halo) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.22),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: halo * 0.5),
            blurRadius: 14,
            spreadRadius: 1,
          ),
        ],
      ),
      child: const Icon(
        Icons.auto_awesome_rounded,
        color: Colors.white,
        size: 20,
      ),
    );
  }
}
