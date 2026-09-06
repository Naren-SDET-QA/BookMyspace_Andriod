/// Represents the reactive state of the speech recognition engine.
sealed class SpeechRecognitionState {
  const SpeechRecognitionState();

  bool get isListening => false;
  bool get hasError => false;
}

class SpeechRecognitionIdle extends SpeechRecognitionState {
  const SpeechRecognitionIdle();
}

class SpeechRecognitionInitializing extends SpeechRecognitionState {
  const SpeechRecognitionInitializing();
}

class SpeechRecognitionListening extends SpeechRecognitionState {
  const SpeechRecognitionListening({
    this.transcript = '',
    this.soundLevel = 0.0,
  });

  final String transcript;
  final double soundLevel;

  @override
  bool get isListening => true;
}

class SpeechRecognitionSuccess extends SpeechRecognitionState {
  const SpeechRecognitionSuccess({
    required this.transcript,
    this.isFinal = true,
  });

  final String transcript;
  final bool isFinal;
}

class SpeechRecognitionError extends SpeechRecognitionState {
  const SpeechRecognitionError({
    required this.message,
    this.isPermissionDenied = false,
    this.isNotSupported = false,
  });

  final String message;
  final bool isPermissionDenied;
  final bool isNotSupported;

  @override
  bool get hasError => true;
}
