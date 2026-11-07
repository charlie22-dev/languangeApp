import 'package:flutter/material.dart';

import '../domain/review_session.dart';

class ReviewRatingButtons extends StatelessWidget {
  const ReviewRatingButtons({
    super.key,
    required this.enabled,
    required this.onRating,
  });
  final bool enabled;
  final ValueChanged<ReviewRating> onRating;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final rating in ReviewRating.values)
          SizedBox(
            width: (constraints.maxWidth - 12) / 2,
            child: OutlinedButton(
              key: ValueKey('rate-${rating.name}'),
              onPressed: enabled ? () => onRating(rating) : null,
              child: Text(rating.label, textAlign: TextAlign.center),
            ),
          ),
      ],
    ),
  );
}
