import 'word.dart';

enum ReviewRating {
  again(1, 'Again'),
  hard(3, 'Hard'),
  good(4, 'Good'),
  easy(5, 'Easy');

  const ReviewRating(this.quality, this.label);
  final int quality;
  final String label;
}

final class ReviewOverview {
  const ReviewOverview({
    required this.dueCount,
    required this.totalCards,
    this.nextDue,
  });
  final int dueCount;
  final int totalCards;
  final DateTime? nextDue;
}

final class ReviewSession {
  ReviewSession({
    required List<Word> cards,
    this.index = 0,
    this.revealed = false,
    this.saving = false,
    this.error,
    Map<ReviewRating, int> ratings = const {},
  }) : cards = List.unmodifiable(cards),
       ratings = Map.unmodifiable(ratings);

  final List<Word> cards;
  final int index;
  final bool revealed;
  final bool saving;
  final String? error;
  final Map<ReviewRating, int> ratings;

  bool get finished => index >= cards.length;
  Word? get currentCard => finished ? null : cards[index];

  ReviewSession copyWith({
    int? index,
    bool? revealed,
    bool? saving,
    String? error,
    Map<ReviewRating, int>? ratings,
  }) => ReviewSession(
    cards: cards,
    index: index ?? this.index,
    revealed: revealed ?? this.revealed,
    saving: saving ?? this.saving,
    error: error,
    ratings: ratings ?? this.ratings,
  );
}
