import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// High-level voice interaction states surfaced to the UI.
enum VoiceState {
  /// Voice features are not available on this platform / permission denied.
  unavailable,

  /// Nothing happening; ready to start.
  idle,

  /// Actively capturing microphone input.
  listening,

  /// Waiting for the agent to respond to a spoken request.
  processing,

  /// Reading an assistant reply aloud.
  speaking,
}

/// Result of [splitSpokenSentences]: the complete sentences ready to speak and
/// how many characters of the input they consumed (so the caller can advance an
/// offset and keep the unterminated tail for the next streamed fragment).
class SpokenSentenceSplit {
  const SpokenSentenceSplit(this.sentences, this.consumed);

  final List<String> sentences;
  final int consumed;
}

/// Sentence boundary: terminal punctuation followed by whitespace, or one or
/// more line breaks (so list items and headings are spoken as their own chunk).
final RegExp _sentenceBoundary = RegExp(r'[.!?…]+\s+|\n+');

/// Splits [pending] into complete sentences for sentence-at-a-time TTS while a
/// reply is still streaming. Only fully terminated sentences are returned unless
/// [flushTail] is true, in which case a trailing partial sentence is emitted too
/// (used when the reply has finished). The trailing boundary whitespace is
/// counted as consumed so the caller's offset lands at the next sentence.
SpokenSentenceSplit splitSpokenSentences(
  String pending, {
  required bool flushTail,
}) {
  final sentences = <String>[];
  var lastEnd = 0;
  for (final match in _sentenceBoundary.allMatches(pending)) {
    final sentence = pending.substring(lastEnd, match.end).trim();
    if (sentence.isNotEmpty) sentences.add(sentence);
    lastEnd = match.end;
  }
  var consumed = lastEnd;
  if (flushTail) {
    final tail = pending.substring(lastEnd).trim();
    if (tail.isNotEmpty) sentences.add(tail);
    consumed = pending.length;
  }
  return SpokenSentenceSplit(sentences, consumed);
}

/// Drives the in-app voice prototype: speech-to-text capture with live
/// transcript, hold-to-talk and hands-free conversation modes, and
/// text-to-speech playback of assistant replies.
///
/// Owned by [AppShellController] so it is reachable wherever the controller is
/// (via `AppShellScope.of(context).voice`). It writes the live transcript into
/// the shared [inputController] — the composer's `TextField` is bound to it, so
/// partial results render with no extra wiring — and triggers a send through
/// [onSend], reusing the existing message pipeline unchanged.
class VoiceController extends ChangeNotifier {
  VoiceController({required this.inputController, required this.onSend});

  /// The composer's text controller. Partial transcripts are written here so
  /// the existing `TextField` shows them live; [onSend] reads from it.
  final TextEditingController inputController;

  /// Sends the current composer text through the normal agent pipeline.
  /// Wired to `AppShellController.sendMessage`.
  final Future<void> Function() onSend;

  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _initialized = false;
  bool _available = false;
  VoiceState _state = VoiceState.idle;
  double _soundLevel = 0;
  bool _conversationMode = false;
  bool _holding = false;
  bool _submitting = false;
  bool _voiceTurn = false;

  // Sentence-chunked TTS of a streaming reply: sentences are spoken as they
  // arrive instead of waiting for the whole answer. The queue feeds one
  // utterance at a time, advanced by the TTS completion handler.
  final List<String> _ttsQueue = <String>[];
  bool _ttsBusy = false;
  bool _replyStreaming = false;
  bool _spokenTurn = false;
  int _spokenChars = 0;

  // STT locale id (e.g. "en_US") and TTS BCP-47 language (e.g. "en-US").
  String _localeId = 'en_US';
  String _ttsLanguage = 'en-US';

  /// Whether voice input/output is usable. The mic button is hidden when false.
  bool get available => _available;

  VoiceState get state => _state;

  /// Latest microphone amplitude (raw plugin value), used for the waveform.
  double get soundLevel => _soundLevel;

  /// True while hands-free conversation mode is engaged.
  bool get conversationMode => _conversationMode;

  /// Whether the in-flight reply is being spoken, so the caller knows it needs
  /// to forward streamed text via [pushReplyText]. False for typed turns, which
  /// lets the streaming hot path skip voice work entirely.
  bool get isVoicingReply => _spokenTurn;

  /// Live transcript shown in the listening overlay.
  String get transcript => inputController.text;

  /// Initializes the speech and TTS engines and resolves the device locale.
  /// Safe to call once; subsequent calls are no-ops.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      _available = await _speech.initialize(
        onError: (_) => _onSpeechError(),
        onStatus: _onSpeechStatus,
      );
    } catch (_) {
      _available = false;
    }
    if (!_available) {
      _setState(VoiceState.unavailable);
      return;
    }
    await _resolveLocale();
    _tts.setCompletionHandler(_onSpeakComplete);
    _tts.setCancelHandler(_onSpeakComplete);
    _tts.setErrorHandler((_) => _onSpeakComplete());
    _setState(VoiceState.idle);
  }

  // ---------------------------------------------------------------------------
  // Public gestures (driven by the mic button).
  // ---------------------------------------------------------------------------

  /// Press-and-hold start: capture a single dictated utterance.
  Future<void> startHold() async {
    if (!_available) return;
    _conversationMode = false;
    _holding = true;
    await _startListening();
  }

  /// Press-and-hold release: stop capturing and send what was transcribed.
  Future<void> stopHold() async {
    if (!_holding) return;
    _holding = false;
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  /// Tap toggle: enter or leave hands-free conversation mode.
  Future<void> toggleConversation() async {
    if (!_available) return;
    if (_conversationMode) {
      await stopConversation();
    } else {
      _conversationMode = true;
      _holding = false;
      await _startListening();
    }
  }

  /// Leaves conversation mode and stops all audio activity.
  Future<void> stopConversation() async {
    _conversationMode = false;
    _holding = false;
    _clearSpeech();
    await _stopSpeaking();
    if (_speech.isListening) {
      await _speech.cancel();
    }
    _setState(VoiceState.idle);
  }

  /// Marks the start of an assistant reply and fixes whether it should be
  /// voiced. Called from `AppShellController.sendMessage` as streaming begins,
  /// so the gate is decided once even though [pushReplyText] arrives in
  /// fragments. Only voice-driven turns (hold/conversation) are spoken.
  void beginSpokenReply() {
    _spokenTurn = (_voiceTurn || _conversationMode) && _available;
    _voiceTurn = false;
    _spokenChars = 0;
    _ttsQueue.clear();
    _ttsBusy = false;
    _replyStreaming = _spokenTurn;
  }

  /// Feeds the cumulative reply [text] streamed so far, speaking any newly
  /// completed sentences. The unterminated tail is held back until more text
  /// arrives or [endSpokenReply] flushes it.
  void pushReplyText(String text) {
    if (!_spokenTurn) return;
    _enqueueSentences(text, flushTail: false);
  }

  /// Marks the reply complete with its full [text]: flushes the final partial
  /// sentence and lets the queue drain. When nothing remains to speak, settles
  /// the state (re-listening in conversation mode), mirroring the end-of-speech
  /// transition the completion handler would otherwise make.
  void endSpokenReply(String text) {
    if (!_spokenTurn) return;
    _enqueueSentences(text, flushTail: true);
    _replyStreaming = false;
    _spokenTurn = false;
    if (!_ttsBusy && _ttsQueue.isEmpty) {
      if (_conversationMode) {
        unawaited(_startListening());
      } else if (_state == VoiceState.speaking ||
          _state == VoiceState.processing) {
        _setState(VoiceState.idle);
      }
    }
  }

  void _enqueueSentences(String cumulative, {required bool flushTail}) {
    if (_spokenChars > cumulative.length) {
      // The streaming buffer was reset (e.g. a tool call cleared a partial
      // answer); restart from the beginning and drop stale pending speech.
      _spokenChars = 0;
      _ttsQueue.clear();
    }
    final split = splitSpokenSentences(
      cumulative.substring(_spokenChars),
      flushTail: flushTail,
    );
    _spokenChars += split.consumed;
    if (split.sentences.isEmpty) return;
    _ttsQueue.addAll(split.sentences);
    // Defer the actual TTS call so it never runs synchronously inside the
    // streaming delta handler (which would fire a reentrant notifyListeners and
    // could stall the on-screen stream). The queue is drained one utterance at a
    // time from here and from the completion handler.
    scheduleMicrotask(() => unawaited(_pumpSpeech()));
  }

  /// Speaks the next queued sentence if the engine is free. Subsequent sentences
  /// are spoken by [_onSpeakComplete] as each utterance finishes.
  Future<void> _pumpSpeech() async {
    if (_ttsBusy || _ttsQueue.isEmpty || !_available) return;
    _ttsBusy = true;
    final next = _ttsQueue.removeAt(0);
    if (_speech.isListening) {
      await _speech.cancel();
    }
    _setState(VoiceState.speaking);
    await _tts.setLanguage(_ttsLanguage);
    await _tts.speak(next);
  }

  /// Drops queued and in-flight speech and closes the spoken-reply gate. Used on
  /// barge-in (starting to listen) and when leaving conversation mode.
  void _clearSpeech() {
    _ttsQueue.clear();
    _ttsBusy = false;
    _replyStreaming = false;
    _spokenTurn = false;
  }

  // ---------------------------------------------------------------------------
  // Internal flow.
  // ---------------------------------------------------------------------------

  Future<void> _startListening() async {
    if (!_available) return;
    // Barge-in: pre-set listening so the TTS cancel handler ignores the stop,
    // and drop any sentences still queued from the reply being interrupted.
    _clearSpeech();
    final wasSpeaking = _state == VoiceState.speaking;
    inputController.clear();
    _soundLevel = 0;
    _setState(VoiceState.listening);
    if (wasSpeaking) {
      await _tts.stop();
    }
    try {
      await _speech.listen(
        onResult: _onResult,
        onSoundLevelChange: _onSoundLevel,
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
          localeId: _localeId,
          // Hold-to-talk waits for release; conversation auto-finalizes on a
          // short pause so turns flow without a button press.
          pauseFor: _holding
              ? const Duration(seconds: 30)
              : const Duration(seconds: 3),
          listenFor: const Duration(seconds: 60),
        ),
      );
    } catch (_) {
      _setState(VoiceState.idle);
    }
  }

  void _onResult(SpeechRecognitionResult result) {
    inputController.text = result.recognizedWords;
    inputController.selection = TextSelection.collapsed(
      offset: inputController.text.length,
    );
    notifyListeners();
    if (result.finalResult) {
      _onFinalResult();
    }
  }

  void _onFinalResult() {
    final hasText = inputController.text.trim().isNotEmpty;
    if (hasText) {
      unawaited(_submit());
    } else if (_conversationMode) {
      unawaited(_startListening());
    } else {
      _setState(VoiceState.idle);
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (inputController.text.trim().isEmpty) {
      _setState(VoiceState.idle);
      return;
    }
    _submitting = true;
    _holding = false;
    _voiceTurn = true;
    _setState(VoiceState.processing);
    try {
      // onSend appends the user message, streams the agent reply (pushReplyText
      // speaks each sentence), then endSpokenReply flushes the final sentence.
      await onSend();
    } catch (_) {
      _setState(_conversationMode ? VoiceState.listening : VoiceState.idle);
    } finally {
      _submitting = false;
    }
  }

  void _onSpeakComplete() {
    // Only act on a natural finish; barge-in pre-sets a non-speaking state.
    if (_state != VoiceState.speaking) return;
    _ttsBusy = false;
    if (_ttsQueue.isNotEmpty) {
      unawaited(_pumpSpeech());
      return;
    }
    // Queue drained: if the reply is still streaming, wait for the next
    // sentence; otherwise the turn is over.
    if (_replyStreaming) return;
    if (_conversationMode) {
      unawaited(_startListening());
    } else {
      _setState(VoiceState.idle);
    }
  }

  void _onSoundLevel(double level) {
    _soundLevel = level;
    notifyListeners();
  }

  void _onSpeechStatus(String status) {
    if (status == SpeechToText.doneStatus ||
        status == SpeechToText.notListeningStatus) {
      _soundLevel = 0;
      // Settle the state if listening ended without producing a submit.
      if (_state == VoiceState.listening && !_submitting) {
        if (_conversationMode) {
          if (inputController.text.trim().isEmpty) {
            unawaited(_startListening());
          }
        } else if (!_holding) {
          _setState(VoiceState.idle);
        }
      }
      notifyListeners();
    }
  }

  void _onSpeechError() {
    _soundLevel = 0;
    if (_state == VoiceState.listening && !_submitting) {
      _conversationMode = false;
      _setState(VoiceState.idle);
    }
  }

  Future<void> _stopSpeaking() async {
    if (_state == VoiceState.speaking) {
      await _tts.stop();
    }
  }

  Future<void> _resolveLocale() async {
    try {
      final system = await _speech.systemLocale();
      if (system != null && system.localeId.trim().isNotEmpty) {
        _localeId = system.localeId.trim();
      }
    } catch (_) {
      // keep default
    }
    final candidate = _localeId.replaceAll('_', '-');
    try {
      final languages = (await _tts.getLanguages) as List<dynamic>?;
      final available = languages
          ?.map((dynamic e) => e.toString())
          .toList(growable: false);
      if (available != null && available.isNotEmpty) {
        final match = available.firstWhere(
          (lang) => lang.toLowerCase() == candidate.toLowerCase(),
          orElse: () => available.firstWhere(
            (lang) => lang.toLowerCase().startsWith(_localeId.split('_').first),
            orElse: () => 'en-US',
          ),
        );
        _ttsLanguage = match;
      } else {
        _ttsLanguage = candidate;
      }
    } catch (_) {
      _ttsLanguage = candidate;
    }
  }

  void _setState(VoiceState next) {
    if (_state == next) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_speech.cancel());
    unawaited(_tts.stop());
    super.dispose();
  }
}
