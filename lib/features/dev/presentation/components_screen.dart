import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/lingo_localizations.dart';
import '../../../core/theme/lingo_tokens.dart';
import '../../../core/theme/appearance_controller.dart';
import '../../../shared/widgets/pip_mascot.dart';
import '../../../shared/widgets/lingo_components.dart';
import '../../../shared/widgets/answer_option.dart';
import '../../../shared/widgets/flippable_flashcard.dart';
import '../../../shared/widgets/responsive_body.dart';
import '../../../shared/widgets/lesson_status_header.dart';
import '../../../shared/widgets/stat_badge.dart';
import '../../home/data/home_providers.dart';
import '../../home/domain/learning_path.dart';
import '../../../shared/widgets/lesson_path_node.dart';

/// Debug-only route. State previews never call grading, recording or chat APIs.
class ComponentsScreen extends ConsumerStatefulWidget {
  const ComponentsScreen({super.key});
  @override
  ConsumerState<ComponentsScreen> createState() => _ComponentsScreenState();
}

class _ComponentsScreenState extends ConsumerState<ComponentsScreen> {
  bool flipped = false;
  int mic = 0;
  @override
  Widget build(BuildContext context) {
    final course = ref.watch(selectedCourseProvider).asData?.value;
    final word = course?.words.firstOrNull;
    final stats = ref.watch(userStatsProvider).asData?.value;
    final appearance = ref.watch(appearanceProvider);
    Widget heading(String id) => Padding(
      padding: const EdgeInsets.symmetric(vertical: LingoSpace.s24),
      child: Text(
        context.l10n.text(id),
        style: Theme.of(context).textTheme.titleLarge,
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.text('components'))),
      body: ResponsiveBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: LingoSpace.s8,
              runSpacing: LingoSpace.s8,
              children: [
                for (final mode in ThemeMode.values)
                  ChoiceChip(
                    label: Text(context.l10n.text(mode.name)),
                    selected: appearance.mode == mode,
                    onSelected: (_) =>
                        ref.read(appearanceProvider.notifier).select(mode),
                  ),
              ],
            ),
            heading('mascot'),
            Wrap(
              spacing: LingoSpace.s16,
              runSpacing: LingoSpace.s16,
              children: [
                for (final mood in PipMood.values) PipMascot(mood: mood),
              ],
            ),
            heading('buttons'),
            LingoButton(
              onPressed: () {},
              child: Text(context.l10n.text('primaryAction')),
            ),
            const SizedBox(height: LingoSpace.s8),
            LingoButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              onPressed: () {},
              child: Text(context.l10n.text('accentAction')),
            ),
            const SizedBox(height: LingoSpace.s8),
            LingoButton.outlined(
              onPressed: () {},
              child: Text(context.l10n.text('secondaryAction')),
            ),
            LingoButton.ghost(
              onPressed: () {},
              child: Text(context.l10n.text('ghostAction')),
            ),
            LingoButton(
              onPressed: null,
              child: Text(context.l10n.text('disabledAction')),
            ),
            heading('inputs'),
            TextFormField(
              decoration: InputDecoration(
                labelText: context.l10n.text('defaultInput'),
              ),
            ),
            const SizedBox(height: LingoSpace.s16),
            TextFormField(
              decoration: InputDecoration(
                labelText: context.l10n.text('errorInput'),
                errorText: context.l10n.text('fieldError'),
              ),
            ),
            heading('answers'),
            for (final state in AnswerVisualState.values)
              AnswerOption(
                label: context.l10n.text(state.name),
                selected: state == AnswerVisualState.selected,
                status: state,
                onTap: () {},
              ),
            heading('progress'),
            const LessonStatusHeader(cleared: 0, total: 0, hearts: 3),
            if (stats != null)
              Wrap(
                spacing: LingoSpace.s8,
                runSpacing: LingoSpace.s8,
                children: [
                  StatBadge(
                    icon: Icons.bolt,
                    label: context.l10n.text('ui122bc8d96b', {
                      'arg0': (stats.xp),
                    }),
                  ),
                  StatBadge(
                    icon: Icons.local_fire_department_outlined,
                    label: context.l10n.text('streakDays', {
                      'count': stats.streak,
                    }),
                  ),
                ],
              ),
            heading('pathNodes'),
            Text(context.l10n.text('previewOnly')),
            if (course != null &&
                course.units.isNotEmpty &&
                course.units.first.lessons.isNotEmpty)
              for (final availability in LessonAvailability.values)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: LingoSpace.s16),
                  child: LessonPathNode(
                    entry: LessonPathEntry(
                      lesson: course.units.first.lessons.first,
                      availability: availability,
                      stars: availability == LessonAvailability.completed
                          ? 3
                          : 0,
                    ),
                    number: 1,
                    onPressed: availability == LessonAvailability.locked
                        ? null
                        : () {},
                  ),
                ),
            heading('flashcard'),
            if (word != null)
              FlippableFlashcard(
                word: word,
                revealed: flipped,
                onFlip: () => setState(() => flipped = !flipped),
              ),
            heading('audioPreview'),
            Text(context.l10n.text('previewOnly')),
            const SizedBox(height: LingoSpace.s16),
            Wrap(
              spacing: LingoSpace.s8,
              runSpacing: LingoSpace.s8,
              children: [
                IconButton(
                  tooltip: context.l10n.text('audioUnavailable'),
                  onPressed: null,
                  icon: const Icon(Icons.volume_up_outlined),
                ),
                LingoButton.outlined(
                  onPressed: null,
                  child: Text(context.l10n.text('slowAudio')),
                ),
              ],
            ),
            heading('microphoneTitle'),
            Wrap(
              spacing: LingoSpace.s8,
              runSpacing: LingoSpace.s8,
              children: [
                for (var i = 0; i < 3; i++)
                  ChoiceChip(
                    label: Text(
                      context.l10n.text(
                        ['micIdle', 'micRecording', 'micUnavailable'][i],
                      ),
                    ),
                    selected: mic == i,
                    onSelected: (_) => setState(() => mic = i),
                  ),
              ],
            ),
            const SizedBox(height: LingoSpace.s16),
            Text(context.l10n.text('previewOnly')),
            heading('chat'),
            ChatBubble(message: context.l10n.text('assistantBubble')),
            ChatBubble(
              message: context.l10n.text('userBubble'),
              fromUser: true,
              correction: context.l10n.text('correctionPreview'),
            ),
            heading('systemStates'),
            const LingoSkeleton(),
            LingoEmptyState(
              title: context.l10n.text('errorTitle'),
              message: context.l10n.text('previewOnly'),
              mood: PipMood.sad,
              action: LingoButton.outlined(
                onPressed: () {},
                child: Text(context.l10n.text('retry')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
