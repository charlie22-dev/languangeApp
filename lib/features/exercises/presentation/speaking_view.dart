import '../../../shared/widgets/speech_permission_dialog.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/lingo_localizations.dart';
import '../../../core/theme/lingo_tokens.dart';
import '../../../shared/widgets/audio_speaker_button.dart';
import '../../../shared/widgets/lingo_components.dart';
import '../../audio/data/audio_service.dart';
import '../../audio/presentation/speaking_controller.dart';
import '../domain/exercise.dart';

class SpeakingView extends ConsumerWidget {
  const SpeakingView({
    super.key,
    required this.exercise,
    required this.enabled,
    required this.onChanged,
    required this.onSkip,
  });
  final Speaking exercise;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final VoidCallback onSkip;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = speakingControllerProvider(exercise);
    final voice = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    ref.listen(
      provider,
      (previous, next) =>
          onChanged(next.busy || next.error != null ? '' : next.transcript),
    );
    Future<void> skip() async {
      await controller.cancel();
      if (context.mounted) onSkip();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.text('sayThisPhrase'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: LingoSpace.s16),
        Text(exercise.phrase, style: Theme.of(context).textTheme.headlineSmall),
        Text(
          context.l10n.text('speechThresholdHint', {
            'score': (exercise.minimumScore * 100).round(),
          }),
        ),
        AudioSpeakerButton(
          text: exercise.phrase,
          audioUrl: exercise.audioUrl,
          enabled: enabled && !voice.busy,
        ),
        const SizedBox(height: LingoSpace.s16),
        LingoButton.outlinedIcon(
          icon: Icon(
            voice.recording ? Icons.stop_circle_outlined : Icons.mic_none,
          ),
          label: Text(
            context.l10n.text(
              voice.preparing
                  ? 'speechPreparing'
                  : voice.recording
                  ? 'stopRecording'
                  : 'startRecording',
            ),
          ),
          onPressed: !enabled || voice.preparing
              ? null
              : () async {
                  if (voice.recording) {
                    await controller.stop();
                    return;
                  }
                  final consent = await showSpeechPermissionDialog(
                    context,
                    bodyKey: 'speechPermissionBody',
                    declineKey: 'skipSpeaking',
                  );
                  if (!context.mounted) return;
                  if (consent == false) {
                    await skip();
                  }
                  if (consent == true) {
                    await controller.start(
                      ref.read(pronunciationLocaleProvider),
                    );
                  }
                },
        ),
        if (voice.busy)
          Padding(
            padding: const EdgeInsets.only(top: LingoSpace.s8),
            child: Text(
              context.l10n.text(
                voice.preparing ? 'speechPreparing' : 'speechListening',
              ),
            ),
          ),
        if (voice.transcript.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: LingoSpace.s16),
            child: Semantics(
              liveRegion: true,
              child: Text(
                context.l10n.text('speechTranscript', {
                  'text': voice.transcript,
                }),
              ),
            ),
          ),
        if (voice.score != null && !voice.busy)
          Text(
            context.l10n.text('speechMatchScore', {
              'score': (voice.score! * 100).round(),
            }),
          ),
        if (voice.error != null)
          Semantics(
            liveRegion: true,
            child: Text(context.l10n.text(voice.error!)),
          ),
        const SizedBox(height: LingoSpace.s16),
        LingoButton.ghost(
          onPressed: enabled ? skip : null,
          child: Text(context.l10n.text('skipSpeaking')),
        ),
      ],
    );
  }
}
