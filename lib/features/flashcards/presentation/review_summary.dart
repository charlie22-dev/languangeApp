import 'package:flutter/material.dart';

import '../domain/review_session.dart';

class ReviewSummary extends StatelessWidget {
  const ReviewSummary({
    super.key,
    required this.session,
    required this.onContinue,
  });
  final ReviewSession session;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Icon(
        Icons.auto_awesome,
        size: 56,
        color: Theme.of(context).colorScheme.primary,
      ),
      const SizedBox(height: 24),
      Text(
        'Review complete!',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 12),
      Text(
        'You reviewed ${session.index} ${session.index == 1 ? 'card' : 'cards'}.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      const SizedBox(height: 24),
      for (final rating in ReviewRating.values)
        Card.filled(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 16,
              runSpacing: 8,
              children: [
                Text(rating.label),
                Text('${session.ratings[rating] ?? 0}'),
              ],
            ),
          ),
        ),
      const SizedBox(height: 24),
      FilledButton(onPressed: onContinue, child: const Text('Continue')),
    ],
  );
}
