import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models/expence.dart';
import '../utils/app_design_system.dart';
import '../utils/voice_expense_parser.dart';
import '../widgets/design_system_components.dart';

/// Bottom sheet that records a short voice phrase, transcribes it via the
/// system speech recognizer, and parses it into a partial [Expense].
///
/// Returns the parsed Expense (or null on cancel) so the caller can open the
/// transaction modal pre-filled for review.
class VoiceCaptureSheet extends StatefulWidget {
  const VoiceCaptureSheet({super.key});

  static Future<Expense?> show(BuildContext context) {
    return showModalBottomSheet<Expense?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (_) => const VoiceCaptureSheet(),
    );
  }

  @override
  State<VoiceCaptureSheet> createState() => _VoiceCaptureSheetState();
}

class _VoiceCaptureSheetState extends State<VoiceCaptureSheet>
    with TickerProviderStateMixin {
  final SpeechToText _speech = SpeechToText();
  late final AnimationController _pulseController;

  bool _initialized = false;
  bool _available = false;
  bool _listening = false;
  String _transcript = '';
  String? _error;
  double _soundLevel = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1100),
      vsync: this,
    )..repeat(reverse: true);
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      final ok = await _speech.initialize(
        onError: (err) {
          if (!mounted) return;
          setState(() {
            _error = err.errorMsg;
            _listening = false;
          });
        },
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'done' || status == 'notListening') {
            setState(() => _listening = false);
          }
        },
      );
      if (!mounted) return;
      setState(() {
        _initialized = true;
        _available = ok;
        if (!ok) {
          _error = 'Microphone unavailable. Check app permissions.';
        }
      });
      if (ok) {
        await _startListening();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initialized = true;
        _available = false;
        _error = 'Speech recognition unavailable on this device.';
      });
    }
  }

  Future<void> _startListening() async {
    if (!_available || _listening) return;
    setState(() {
      _error = null;
      _transcript = '';
      _listening = true;
    });
    await HapticFeedback.lightImpact();
    if (!mounted) return;
    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() => _transcript = result.recognizedWords);
      },
      onSoundLevelChange: (level) {
        if (!mounted) return;
        setState(() => _soundLevel = level);
      },
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: true,
      ),
      pauseFor: const Duration(seconds: 3),
      listenFor: const Duration(seconds: 30),
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    if (!mounted) return;
    setState(() => _listening = false);
  }

  void _useTranscript() {
    if (_transcript.trim().isEmpty) return;
    final parsed = VoiceExpenseParser.parse(_transcript);
    if (parsed == null) {
      setState(() => _error =
          "Couldn't find an amount in that. Try \"250 for coffee\".");
      return;
    }
    HapticFeedback.mediumImpact();
    Navigator.pop(context, parsed);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final canUse = _transcript.trim().isNotEmpty && !_listening;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppDesignSystem.darkCanvas
            : AppDesignSystem.lightCanvas,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppDesignSystem.r24),
        ),
      ),
      padding: EdgeInsets.only(
        left: AppDesignSystem.s20,
        right: AppDesignSystem.s20,
        top: AppDesignSystem.s12,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppDesignSystem.s24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.12),
                borderRadius:
                    BorderRadius.circular(AppDesignSystem.rFull),
              ),
            ),
          ),
          const VSpace.lg(),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:
                      AppDesignSystem.brandPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppDesignSystem.r12),
                ),
                child: const Icon(
                  Icons.graphic_eq_rounded,
                  color: AppDesignSystem.brandPrimary,
                  size: 22,
                ),
              ),
              const HSpace.md(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Voice Quick-Add',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Say something like "250 for coffee"',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const VSpace.xl(),

          // Mic visualisation
          GestureDetector(
            onTap: _listening ? _stopListening : _startListening,
            child: _MicVisualizer(
              listening: _listening,
              soundLevel: _soundLevel,
              pulseController: _pulseController,
              available: _available && _initialized,
            ),
          ),

          const VSpace.lg(),
          Center(
            child: Text(
              !_initialized
                  ? 'Preparing microphone…'
                  : !_available
                      ? 'Tap to retry'
                      : _listening
                          ? 'Listening…  tap mic to stop'
                          : _transcript.isEmpty
                              ? 'Tap the mic to start'
                              : 'Tap mic to record again',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const VSpace.lg(),

          // Transcript card
          AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.all(AppDesignSystem.s16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.025),
              borderRadius: BorderRadius.circular(AppDesignSystem.r16),
              border: Border.all(
                color: _transcript.isNotEmpty
                    ? AppDesignSystem.brandPrimary.withValues(alpha: 0.4)
                    : theme.colorScheme.outline.withValues(alpha: 0.15),
                width: _transcript.isNotEmpty ? 1.5 : 1,
              ),
            ),
            child: Text(
              _transcript.isEmpty
                  ? 'Your transcript will appear here'
                  : _transcript,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: _transcript.isEmpty
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.35)
                    : theme.colorScheme.onSurface,
                fontWeight:
                    _transcript.isEmpty ? FontWeight.w500 : FontWeight.w700,
                fontStyle: _transcript.isEmpty
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
            ),
          ),

          if (_error != null) ...[
            const VSpace.md(),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppDesignSystem.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppDesignSystem.r12),
                border: Border.all(
                  color: AppDesignSystem.error.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 16, color: AppDesignSystem.error),
                  const HSpace.sm(),
                  Expanded(
                    child: Text(
                      _error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppDesignSystem.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const VSpace.xl(),

          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  text: 'Cancel',
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const HSpace.md(),
              Expanded(
                child: GradientButton(
                  text: 'Use This',
                  icon: Icons.check_rounded,
                  onPressed: canUse ? _useTranscript : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MicVisualizer extends StatelessWidget {
  final bool listening;
  final double soundLevel;
  final AnimationController pulseController;
  final bool available;

  const _MicVisualizer({
    required this.listening,
    required this.soundLevel,
    required this.pulseController,
    required this.available,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // soundLevel from speech_to_text is roughly -2..10 on Android
    final normalized = (soundLevel.clamp(-2.0, 10.0) + 2) / 12;

    return AnimatedBuilder(
      animation: pulseController,
      builder: (context, _) {
        final pulse = listening
            ? 1.0 + (pulseController.value * 0.12) + (normalized * 0.18)
            : 1.0;
        return Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (listening) ...[
                _Ring(
                  size: 140 * pulse,
                  color: AppDesignSystem.brandPrimary
                      .withValues(alpha: 0.08),
                ),
                _Ring(
                  size: 110 * pulse,
                  color: AppDesignSystem.brandPrimary
                      .withValues(alpha: 0.14),
                ),
              ],
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  gradient: AppDesignSystem.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppDesignSystem.brandPrimary
                          .withValues(alpha: listening ? 0.55 : 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  listening
                      ? Icons.mic_rounded
                      : available
                          ? Icons.mic_none_rounded
                          : Icons.mic_off_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
              if (!listening && available)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppDesignSystem.brandPrimary
                            .withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.touch_app_rounded,
                      size: 14,
                      color: AppDesignSystem.brandPrimary,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Ring extends StatelessWidget {
  final double size;
  final Color color;

  const _Ring({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
