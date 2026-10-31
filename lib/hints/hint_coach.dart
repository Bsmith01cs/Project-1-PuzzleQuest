import '../settings/settings_controller.dart';

enum HintKind { clue, firstLetter }

/// A hint HintCoach is willing to offer, together with the reason it applies.
/// Nothing is revealed until the player accepts it.
class HintSuggestion {
  const HintSuggestion({required this.kind, required this.explanation});

  final HintKind kind;
  final String explanation;
}

/// Reports why the counters HintCoach was given cannot be used, or null when
/// they are usable. A corrupted attempt row or a puzzle without an answer
/// stops hints entirely rather than falling back to a weaker hint.
String? validateHintInputs({
  required int wrongGuesses,
  required int elapsedSeconds,
  required int answerLength,
}) {
  if (wrongGuesses < 0) {
    return 'Hints are unavailable: the wrong guess count is invalid.';
  }
  if (elapsedSeconds < 0) {
    return 'Hints are unavailable: the elapsed time is invalid.';
  }
  if (answerLength <= 0) {
    return 'Hints are unavailable: this puzzle has no answer to hint at.';
  }
  return null;
}

/// HintCoach rules, applied in order:
///
/// 0. Invalid counters (see [validateHintInputs]) earn no hint at all.
/// 1. No hint until the player has guessed wrong at least once or has reached
///    the saved time threshold.
/// 2. Two or more wrong guesses *and* the threshold reached earns the first
///    letter, but only for answers longer than four letters.
/// 3. Anything else earns the clue.
///
/// A threshold outside the saved range is clamped back into it, so a stale
/// setting cannot unlock or block hints.
HintSuggestion? suggestHint({
  required int wrongGuesses,
  required int elapsedSeconds,
  required int thresholdSeconds,
  required int answerLength,
}) {
  final invalid = validateHintInputs(
    wrongGuesses: wrongGuesses,
    elapsedSeconds: elapsedSeconds,
    answerLength: answerLength,
  );
  if (invalid != null) {
    return null;
  }

  final threshold = clampHintThreshold(thresholdSeconds);
  final reachedThreshold = elapsedSeconds >= threshold;
  if (wrongGuesses < 1 && !reachedThreshold) {
    return null;
  }

  if (wrongGuesses >= 2 && reachedThreshold && answerLength > 4) {
    return HintSuggestion(
      kind: HintKind.firstLetter,
      explanation:
          'You have $wrongGuesses wrong guesses and have passed $threshold '
          'seconds, and the answer is longer than four letters, so the first '
          'letter is available.',
    );
  }

  final reason = wrongGuesses >= 1
      ? 'You have $wrongGuesses wrong '
            '${wrongGuesses == 1 ? 'guess' : 'guesses'}'
      : 'You have passed $threshold seconds';

  return HintSuggestion(
    kind: HintKind.clue,
    explanation: '$reason, so the clue is the hint on offer.',
  );
}

/// The fixed-rule baseline HintCoach is measured against: the clue after the
/// first wrong guess, with no regard for time or answer length.
HintSuggestion? suggestBaselineHint({required int wrongGuesses}) {
  final misses = wrongGuesses < 0 ? 0 : wrongGuesses;
  if (misses < 1) {
    return null;
  }

  return const HintSuggestion(
    kind: HintKind.clue,
    explanation: 'A wrong guess was made, so the clue is offered.',
  );
}

/// The text a hint shows once the player accepts it. The clue is never
/// printed twice: when it is already on screen the hint points at it instead.
String hintText({
  required HintKind kind,
  required String answer,
  required String clue,
  required bool clueVisible,
}) {
  switch (kind) {
    case HintKind.firstLetter:
      if (answer.isEmpty) {
        return clueVisible ? 'Read the clue above once more.' : clue;
      }
      return 'The answer starts with "${answer[0].toUpperCase()}".';
    case HintKind.clue:
      return clueVisible ? 'Read the clue above once more.' : clue;
  }
}
