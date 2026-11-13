import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/features/audio/domain/speech_similarity.dart';

void main() {
  test('case punctuation and spaces normalize', () {
    expect(normalizeSpeech('  Hello, WORLD!  '), 'helloworld');
    expect(speechSimilarity('Hello, world!', 'HELLO WORLD'), 1);
  });
  test('identical Japanese has full similarity and punctuation is ignored', () {
    expect(speechSimilarity('こんにちは。', 'こ んにちは！'), 1);
  });
  test(
    'silence never earns a score even when both inputs normalize to empty',
    () {
      expect(speechSimilarity('', ''), 0);
      expect(speechSimilarity('hello', '  ... '), 0);
      expect(speechSimilarity('...', 'hello'), 0);
    },
  );
  test('substitution insertion and deletion have expected ratios', () {
    expect(speechSimilarity('hello', 'hallo'), closeTo(.8, 1e-10));
    expect(speechSimilarity('cat', 'cats'), closeTo(.75, 1e-10));
    expect(speechSimilarity('cats', 'cat'), closeTo(.75, 1e-10));
  });
  test('classic Levenshtein example and symmetry', () {
    expect(speechSimilarity('kitten', 'sitting'), closeTo(4 / 7, 1e-10));
    expect(speechSimilarity('sitting', 'kitten'), closeTo(4 / 7, 1e-10));
  });
  test(
    'unrelated text scores zero',
    () => expect(speechSimilarity('abc', 'xyz'), 0),
  );
  test('diacritics and non-Latin letters retain their meaning', () {
    expect(speechSimilarity('sí', 'si'), .5);
    expect(normalizeSpeech('안녕하세요。'), '안녕하세요');
  });
  test('Japanese edits count characters rather than UTF-16 bytes', () {
    expect(speechSimilarity('ありがとう', 'ありがと'), closeTo(.8, 1e-10));
    expect(speechSimilarity('𠮷野', '𠮷田'), .5);
  });
}
