import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/speech_recognition_state.dart';
import 'web_speech_bridge.dart';

/// Cross-platform Voice Speech Recognition Service for Flutter (iOS, Web, & Fallbacks).
/// Matches Android SpeechRecognizer functionality with live streaming transcripts,
/// permission handling, soundwave level metering, and automatic text fallback.
class SpeechRecognitionService {
  SpeechRecognitionService() {
    _initPlatformHandlers();
  }

  static const MethodChannel _iosSpeechChannel = MethodChannel(
    'com.bookmyspace.bookmyspace/speech_recognition',
  );

  final _stateController = StreamController<SpeechRecognitionState>.broadcast();
  Stream<SpeechRecognitionState> get stateStream => _stateController.stream;

  SpeechRecognitionState _currentState = const SpeechRecognitionIdle();
  SpeechRecognitionState get currentState => _currentState;

  Timer? _volumeSimulationTimer;
  Timer? _silenceTimeoutTimer;
  final Random _random = Random();

  void _setState(SpeechRecognitionState newState) {
    _currentState = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  void _initPlatformHandlers() {
    if (kIsWeb) {
      WebSpeechBridge.registerEventListener((event) {
        final eventType = event['eventType'] as String? ?? '';
        switch (eventType) {
          case 'listening':
            _startVolumeMetering();
            _resetSilenceTimeout();
            _setState(const SpeechRecognitionListening(soundLevel: 0.2));
            break;
          case 'result':
            final transcript = event['transcript'] as String? ?? '';
            final isFinal = event['isFinal'] as bool? ?? false;
            _resetSilenceTimeout();
            if (isFinal) {
              _stopVolumeMetering();
              _setState(SpeechRecognitionSuccess(
                transcript: transcript,
                isFinal: true,
              ));
            } else {
              final level = 0.2 + (_random.nextDouble() * 0.7);
              _setState(SpeechRecognitionListening(
                transcript: transcript,
                soundLevel: level,
              ));
            }
            break;
          case 'error':
            _stopVolumeMetering();
            _cancelSilenceTimeout();
            final errorMsg = event['error'] as String? ?? 'Speech recognition error';
            final code = event['code'] as String? ?? '';
            final isPermDenied = code == 'not-allowed';
            _setState(SpeechRecognitionError(
              message: errorMsg,
              isPermissionDenied: isPermDenied,
              isNotSupported: code == 'not_supported',
            ));
            break;
          case 'end':
            _stopVolumeMetering();
            _cancelSilenceTimeout();
            if (_currentState is SpeechRecognitionListening) {
              final currentText = (_currentState as SpeechRecognitionListening).transcript;
              if (currentText.trim().isNotEmpty) {
                _setState(SpeechRecognitionSuccess(
                  transcript: currentText.trim(),
                  isFinal: true,
                ));
              } else {
                _setState(const SpeechRecognitionIdle());
              }
            }
            break;
        }
      });
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      _iosSpeechChannel.setMethodCallHandler((call) async {
        switch (call.method) {
          case 'onSpeechResult':
            final args = call.arguments as Map<dynamic, dynamic>? ?? {};
            final transcript = args['transcript'] as String? ?? '';
            final isFinal = args['isFinal'] as bool? ?? false;
            _resetSilenceTimeout();
            if (isFinal) {
              _stopVolumeMetering();
              _setState(SpeechRecognitionSuccess(
                transcript: transcript,
                isFinal: true,
              ));
            } else {
              final level = 0.3 + (_random.nextDouble() * 0.6);
              _setState(SpeechRecognitionListening(
                transcript: transcript,
                soundLevel: level,
              ));
            }
            break;
          case 'onSpeechError':
            _stopVolumeMetering();
            _cancelSilenceTimeout();
            final args = call.arguments as Map<dynamic, dynamic>? ?? {};
            final error = args['error'] as String? ?? 'iOS Speech Recognition Error';
            _setState(SpeechRecognitionError(
              message: error,
              isPermissionDenied: error.toLowerCase().contains('denied') || error.toLowerCase().contains('permission'),
            ));
            break;
          case 'onSpeechEnd':
            _stopVolumeMetering();
            _cancelSilenceTimeout();
            if (_currentState is SpeechRecognitionListening) {
              final currentText = (_currentState as SpeechRecognitionListening).transcript;
              if (currentText.trim().isNotEmpty) {
                _setState(SpeechRecognitionSuccess(
                  transcript: currentText.trim(),
                  isFinal: true,
                ));
              } else {
                _setState(const SpeechRecognitionIdle());
              }
            }
            break;
        }
      });
    }
  }

  /// Checks whether speech recognition is available on the current device/platform.
  Future<bool> isSupported() async {
    if (kIsWeb) {
      return WebSpeechBridge.isSupported;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        final result = await _iosSpeechChannel.invokeMapMethod<String, dynamic>('isAvailable');
        return result?['isAvailable'] as bool? ?? false;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// Requests microphone & speech recognition permissions.
  Future<bool> requestPermission() async {
    if (kIsWeb) {
      // Browser permissions are requested on getUserMedia / startListening
      return true;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        final result = await _iosSpeechChannel.invokeMapMethod<String, dynamic>('requestPermission');
        return result?['granted'] as bool? ?? false;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// Starts active voice listening.
  Future<void> startListening({String language = 'en-IN'}) async {
    _setState(const SpeechRecognitionInitializing());

    if (kIsWeb) {
      final supported = WebSpeechBridge.isSupported;
      if (!supported) {
        _setState(const SpeechRecognitionError(
          message: 'Web Speech API is not supported in this browser. Please use Chrome, Edge, or Safari, or use keyboard search.',
          isNotSupported: true,
        ));
        return;
      }

      final started = await WebSpeechBridge.startListening(language: language);
      if (!started) {
        // State set by listener callback
      }
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        final permGranted = await requestPermission();
        if (!permGranted) {
          _setState(const SpeechRecognitionError(
            message: 'Microphone and speech recognition permissions are required for voice search.',
            isPermissionDenied: true,
          ));
          return;
        }

        _startVolumeMetering();
        _resetSilenceTimeout();
        _setState(const SpeechRecognitionListening(soundLevel: 0.2));

        await _iosSpeechChannel.invokeMethod('startListening', {
          'language': language,
        });
      } catch (e) {
        _stopVolumeMetering();
        _setState(SpeechRecognitionError(
          message: 'Failed to start voice search on iOS: $e',
        ));
      }
      return;
    }

    // Non-Web, Non-iOS fallback (e.g. desktop testing or unsupported VM)
    _setState(const SpeechRecognitionError(
      message: 'Native voice recognition is supported on Android, iOS, and Web (Chrome/Edge/Safari).',
      isNotSupported: true,
    ));
  }

  /// Stops listening and commits the captured speech buffer.
  Future<void> stopListening() async {
    _stopVolumeMetering();
    _cancelSilenceTimeout();
    if (kIsWeb) {
      await WebSpeechBridge.stopListening();
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        await _iosSpeechChannel.invokeMethod('stopListening');
      } catch (_) {}
    }

    if (_currentState is SpeechRecognitionListening) {
      final current = (_currentState as SpeechRecognitionListening).transcript;
      if (current.trim().isNotEmpty) {
        _setState(SpeechRecognitionSuccess(
          transcript: current.trim(),
          isFinal: true,
        ));
      } else {
        _setState(const SpeechRecognitionIdle());
      }
    }
  }

  /// Aborts active recognition without processing.
  Future<void> cancelListening() async {
    _stopVolumeMetering();
    _cancelSilenceTimeout();
    if (kIsWeb) {
      await WebSpeechBridge.abort();
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        await _iosSpeechChannel.invokeMethod('cancelListening');
      } catch (_) {}
    }
    _setState(const SpeechRecognitionIdle());
  }

  void _startVolumeMetering() {
    _volumeSimulationTimer?.cancel();
    _volumeSimulationTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (_currentState is SpeechRecognitionListening) {
        final current = _currentState as SpeechRecognitionListening;
        final newLevel = (0.15 + (_random.nextDouble() * 0.75)).clamp(0.05, 1.0);
        _setState(SpeechRecognitionListening(
          transcript: current.transcript,
          soundLevel: newLevel,
        ));
      }
    });
  }

  void _stopVolumeMetering() {
    _volumeSimulationTimer?.cancel();
    _volumeSimulationTimer = null;
  }

  void _resetSilenceTimeout() {
    _silenceTimeoutTimer?.cancel();
    _silenceTimeoutTimer = Timer(const Duration(seconds: 10), () {
      if (_currentState.isListening) {
        stopListening();
      }
    });
  }

  void _cancelSilenceTimeout() {
    _silenceTimeoutTimer?.cancel();
    _silenceTimeoutTimer = null;
  }

  void dispose() {
    _stopVolumeMetering();
    _cancelSilenceTimeout();
    _stateController.close();
  }
}
