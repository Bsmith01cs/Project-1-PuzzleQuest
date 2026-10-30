import 'package:flutter_test/flutter_test.dart';

import 'package:puzzle_quest/screens/editor_screen.dart';

void main() {
  group('validateAnswer', () {
    test('accepts a well-formed answer', () {
      expect(validateAnswer('FLUTTER'), isNull);
    });

    test('accepts lowercase input because answers are upper-cased', () {
      expect(validateAnswer('flutter'), isNull);
    });

    test('accepts the 4 and 12 letter boundaries', () {
      expect(validateAnswer('DART'), isNull);
      expect(validateAnswer('ABCDEFGHIJKL'), isNull);
    });

    test('rejects blank input', () {
      expect(validateAnswer(''), 'Enter an answer.');
      expect(validateAnswer('   '), 'Enter an answer.');
      expect(validateAnswer(null), 'Enter an answer.');
    });

    test('rejects digits, spaces and punctuation', () {
      expect(validateAnswer('PUZZLE1'), 'Use letters only.');
      expect(validateAnswer('TWO WORDS'), 'Use letters only.');
      expect(validateAnswer('CO-OP'), 'Use letters only.');
    });

    test('rejects answers outside 4 to 12 letters', () {
      expect(validateAnswer('CAT'), 'Use 4 to 12 letters.');
      expect(validateAnswer('ABCDEFGHIJKLM'), 'Use 4 to 12 letters.');
    });

    test('rejects an answer built from one repeated letter', () {
      expect(validateAnswer('AAAA'), 'Use more than one distinct letter.');
      expect(validateAnswer('zzzzzz'), 'Use more than one distinct letter.');
    });

    test('allows repeated letters when more than one letter is used', () {
      expect(validateAnswer('BOOKKEEPER'), isNull);
    });
  });

  group('validateClue', () {
    test('accepts a normal clue', () {
      expect(validateClue('Toolkit used to build this app'), isNull);
    });

    test('rejects a blank clue', () {
      expect(validateClue(''), 'Enter a clue.');
      expect(validateClue('   '), 'Enter a clue.');
    });

    test('accepts a clue at the length limit', () {
      expect(validateClue('a' * maxClueLength), isNull);
    });

    test('rejects a clue over the length limit', () {
      expect(
        validateClue('a' * (maxClueLength + 1)),
        'Keep the clue to $maxClueLength characters or fewer.',
      );
    });
  });

  group('validateCategory', () {
    test('accepts a normal category', () {
      expect(validateCategory('Technology'), isNull);
    });

    test('rejects a blank category', () {
      expect(validateCategory('  '), 'Enter a category.');
    });

    test('rejects a category over the length limit', () {
      expect(
        validateCategory('a' * (maxCategoryLength + 1)),
        'Keep the category to $maxCategoryLength characters or fewer.',
      );
    });
  });

  group('difficultyLabel', () {
    test('maps each stored difficulty to a label', () {
      expect(difficultyLabel(1), 'Easy');
      expect(difficultyLabel(2), 'Medium');
      expect(difficultyLabel(3), 'Hard');
    });
  });
}
