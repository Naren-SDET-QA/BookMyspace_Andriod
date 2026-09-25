import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/speech_recognition_state.dart';
import '../domain/voice_filter_parser.dart';
import '../infrastructure/speech_recognition_service.dart';

/// Provider for the singleton/lifecycle-managed SpeechRecognitionService.
final speechRecognitionServiceProvider =
    Provider.autoDispose<SpeechRecognitionService>((ref) {
  final service = SpeechRecognitionService();
  ref.onDispose(service.dispose);
  return service;
});

/// Stream provider for reactive UI listening states.
final speechRecognitionStateProvider =
    StreamProvider.autoDispose<SpeechRecognitionState>((ref) {
  final service = ref.watch(speechRecognitionServiceProvider);
  return service.stateStream;
});

/// Provider to parse spoken speech query text into structured filters.
final parsedVoiceFilterProvider =
    Provider.family<VoiceFilterResult, String>((ref, spokenText) {
  return VoiceCommandFilterParser.parse(spokenText);
});
