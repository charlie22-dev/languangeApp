/// Letter/number comparison ignores punctuation and whitespace, including the
/// inconsistent spaces recognizers insert into Japanese. Accents are retained.
String normalizeSpeech(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');

/// Unicode-code-point Levenshtein ratio, bounded to [0, 1]. Silence never passes.
double speechSimilarity(String target, String transcript) {
  final a = normalizeSpeech(target).runes.toList();
  final b = normalizeSpeech(transcript).runes.toList();
  if (a.isEmpty || b.isEmpty) return 0;
  var previous = List.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final current = List.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final deletion = previous[j] + 1;
      final insertion = current[j - 1] + 1;
      final substitution = previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1);
      current[j] = [
        deletion,
        insertion,
        substitution,
      ].reduce((x, y) => x < y ? x : y);
    }
    previous = current;
  }
  return 1 - previous.last / (a.length > b.length ? a.length : b.length);
}
