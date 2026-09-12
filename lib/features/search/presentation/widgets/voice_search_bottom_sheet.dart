import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/speech_recognition_state.dart';
import '../../domain/voice_filter_parser.dart';
import '../../infrastructure/speech_recognition_service.dart';
import '../voice_search_providers.dart';

/// Interactive Voice Search Modal Bottom Sheet for iOS, Web, and mobile.
class VoiceSearchBottomSheet extends ConsumerStatefulWidget {
  const VoiceSearchBottomSheet({
    super.key,
    required this.onFilterApplied,
    this.onFallbackToText,
  });

  final void Function(VoiceFilterResult result) onFilterApplied;
  final VoidCallback? onFallbackToText;

  static Future<void> show(
    BuildContext context, {
    required void Function(VoiceFilterResult result) onFilterApplied,
    VoidCallback? onFallbackToText,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VoiceSearchBottomSheet(
        onFilterApplied: onFilterApplied,
        onFallbackToText: onFallbackToText,
      ),
    );
  }

  @override
  ConsumerState<VoiceSearchBottomSheet> createState() =>
      _VoiceSearchBottomSheetState();
}

class _VoiceSearchBottomSheetState extends ConsumerState<VoiceSearchBottomSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final SpeechRecognitionService _speechService;

  StreamSubscription<SpeechRecognitionState>? _stateSub;
  SpeechRecognitionState _state = const SpeechRecognitionInitializing();
  String _currentTranscript = '';
  VoiceFilterResult? _parsedResult;
  Timer? _autoApplyTimer;

  static const List<String> _sampleVoicePrompts = [
    'Badminton courts in Hyderabad under 1000',
    'Function halls in Gachibowli',
    'Gents PG near Hitec City',
    'Football turf with lights',
    'Clear filters',
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _speechService = ref.read(speechRecognitionServiceProvider);

    _stateSub = _speechService.stateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _state = state;
        if (state is SpeechRecognitionListening) {
          if (state.transcript.isNotEmpty) {
            _currentTranscript = state.transcript;
            _parsedResult = VoiceCommandFilterParser.parse(_currentTranscript);
          }
        } else if (state is SpeechRecognitionSuccess) {
          _currentTranscript = state.transcript;
          _parsedResult = VoiceCommandFilterParser.parse(_currentTranscript);
          // Automatically apply filter after short visual confirmation
          _autoApplyTimer?.cancel();
          _autoApplyTimer = Timer(const Duration(milliseconds: 1200), () {
            if (mounted && _parsedResult != null) {
              _applyAndClose(_parsedResult!);
            }
          });
        }
      });
    });

    // Automatically initiate speech listening on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startListening();
    });
  }

  @override
  void dispose() {
    _autoApplyTimer?.cancel();
    _stateSub?.cancel();
    _pulseController.dispose();
    _speechService.cancelListening();
    super.dispose();
  }

  Future<void> _startListening() async {
    _autoApplyTimer?.cancel();
    setState(() {
      _state = const SpeechRecognitionInitializing();
      _currentTranscript = '';
      _parsedResult = null;
    });
    await _speechService.startListening(language: 'en-IN');
  }

  void _applyAndClose(VoiceFilterResult result) {
    widget.onFilterApplied(result);
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _onSamplePromptTapped(String prompt) {
    _autoApplyTimer?.cancel();
    _speechService.cancelListening();
    setState(() {
      _currentTranscript = prompt;
      _parsedResult = VoiceCommandFilterParser.parse(prompt);
      _state = SpeechRecognitionSuccess(transcript: prompt, isFinal: true);
    });
    _autoApplyTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted && _parsedResult != null) {
        _applyAndClose(_parsedResult!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isListening = _state is SpeechRecognitionListening;
    final soundLevel =
        isListening ? (_state as SpeechRecognitionListening).soundLevel : 0.0;
    final isSuccess = _state is SpeechRecognitionSuccess;
    final isError = _state is SpeechRecognitionError;
    final errorObj = isError ? (_state as SpeechRecognitionError) : null;

    return Container(
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
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header Title & Cancel
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.brand.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child:
                        const Icon(Icons.mic, color: AppTheme.brand, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Voice Search',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Close',
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Pulsing Mic and Visualizer
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer Ripple
                if (isListening)
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      final scale = _pulseAnimation.value + (soundLevel * 0.3);
                      return Container(
                        width: 120 * scale,
                        height: 120 * scale,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.brand
                              .withValues(alpha: 0.15 * (1.0 - (scale - 1.0))),
                        ),
                      );
                    },
                  ),

                // Main Mic Button
                GestureDetector(
                  onTap: () {
                    if (isListening) {
                      _speechService.stopListening();
                    } else {
                      _startListening();
                    }
                  },
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: isError
                            ? [
                                theme.colorScheme.error,
                                theme.colorScheme.error.withValues(alpha: 0.8)
                              ]
                            : isSuccess
                                ? [Colors.green, Colors.teal]
                                : [AppTheme.brand, AppTheme.brandDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isError
                                  ? theme.colorScheme.error
                                  : isSuccess
                                      ? Colors.green
                                      : AppTheme.brand)
                              .withValues(alpha: 0.4),
                          blurRadius: 16,
                          spreadRadius: isListening ? 4 : 1,
                        ),
                      ],
                    ),
                    child: Icon(
                      isListening
                          ? Icons.mic_rounded
                          : isSuccess
                              ? Icons.check_rounded
                              : isError
                                  ? Icons.mic_off_rounded
                                  : Icons.mic_none_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Sound Wave Bars (Visualizer)
          if (isListening) ...[
            SizedBox(
              height: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(7, (index) {
                  final offset = (index - 3).abs();
                  final barHeight =
                      (8 + ((soundLevel * 20) / (offset + 1))).clamp(6.0, 24.0);
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    width: 4,
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: AppTheme.brand,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Transcription or Status Text
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSuccess
                    ? Colors.green.withValues(alpha: 0.4)
                    : isError
                        ? theme.colorScheme.error.withValues(alpha: 0.3)
                        : theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              children: [
                Text(
                  _currentTranscript.isNotEmpty
                      ? '"$_currentTranscript"'
                      : isListening
                          ? 'Listening... Speak naturally'
                          : isError
                              ? errorObj?.message ?? 'Microphone error'
                              : 'Tap microphone and start speaking',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: _currentTranscript.isNotEmpty
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: isError
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurface,
                    fontStyle: _currentTranscript.isEmpty
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (isListening && _currentTranscript.isEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Try: "Function halls in Hyderabad under 50k"',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Parsed Badges Preview
          if (_parsedResult != null && _parsedResult!.badges.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: _parsedResult!.badges.map((badge) {
                return Chip(
                  avatar: Text(badge.iconEmoji),
                  label: Text(
                    '${badge.title}: ${badge.value}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  backgroundColor:
                      theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                  side: BorderSide.none,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                );
              }).toList(),
            ),
          ],

          // Error Fallback Action Buttons
          if (isError) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _startListening,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Try Again'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onFallbackToText?.call();
                  },
                  icon: const Icon(Icons.keyboard_rounded, size: 18),
                  label: const Text('Type Search Instead'),
                ),
              ],
            ),
          ],

          // If speech is recognized, show Apply Button
          if (_parsedResult != null && !isError) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _applyAndClose(_parsedResult!),
                icon: const Icon(Icons.check_circle_rounded),
                label: Text(
                  _parsedResult!.isClearCommand
                      ? 'Clear All Filters'
                      : 'Apply Search & View Results',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: AppTheme.brand,
                ),
              ),
            ),
          ],

          // Sample Suggestions Carousel
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Or tap a quick search:',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _sampleVoicePrompts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final prompt = _sampleVoicePrompts[index];
                return ActionChip(
                  label: Text(prompt, style: const TextStyle(fontSize: 12)),
                  onPressed: () => _onSamplePromptTapped(prompt),
                  backgroundColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
