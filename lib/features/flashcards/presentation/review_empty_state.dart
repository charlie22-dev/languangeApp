import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/review_session.dart';

class ReviewEmptyState extends StatelessWidget {
  const ReviewEmptyState({super.key, required this.overview});
  final ReviewOverview overview;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Icon(
        Icons.task_alt,
        size: 56,
        color: Theme.of(context).colorScheme.primary,
      ),
      const SizedBox(height: 24),
      Text(
        overview.totalCards == 0
            ? 'Your review deck is ready to grow.'
            : 'All caught up!',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 12),
      Text(
        overview.nextDue == null
            ? 'Complete a lesson to add words to your review deck.'
            : 'Next card due ${DateFormat('EEE, MMM d, y • h:mm a').format(overview.nextDue!.toLocal())}.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    ],
  );
}
