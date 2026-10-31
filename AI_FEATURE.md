# HintCoach

HintCoach is PuzzleQuest's intelligent feature. It decides **whether** a hint is
earned and **which** hint is appropriate, then offers it for the player to
accept or decline. It is a transparent rule system running entirely on the
device: no cloud service, no trained model, no extra packages. Every decision
can be read off the three inputs below.

## Inputs

| Input | Source |
| --- | --- |
| Wrong guesses in the current attempt | `PlayScreen` state, persisted in `attempts.wrong_guesses` |
| Elapsed seconds in the current attempt | `PlayScreen` timer, persisted in `attempts.elapsed_seconds` |
| Hint threshold (30–120 s, default 60) | `SettingsController`, persisted in `SharedPreferences` |
| Answer length | The puzzle being played |

## Rules

Implemented in `suggestHint` in `lib/hints/hint_coach.dart`, evaluated in order:

0. **Invalid counters** — a negative wrong guess count, a negative elapsed
   time, or an answer length of zero or less. No hint is offered at all and
   the Play screen states why.
1. **No hint yet** — fewer than one wrong guess *and* the threshold not
   reached. Nothing is offered.
2. **First letter** — two or more wrong guesses *and* the threshold reached
   *and* the answer is longer than four letters.
3. **Clue** — every other case where rules 0 and 1 do not apply.

Rule 0 is `validateHintInputs`, which returns the message shown to the player:

| Condition | Message |
| --- | --- |
| `wrongGuesses < 0` | Hints are unavailable: the wrong guess count is invalid. |
| `elapsedSeconds < 0` | Hints are unavailable: the elapsed time is invalid. |
| `answerLength <= 0` | Hints are unavailable: this puzzle has no answer to hint at. |

Invalid counters stop hints outright rather than degrading to a weaker hint, so
a corrupted attempt row can never be the reason a hint appears.

The threshold is a saved setting rather than attempt data, so a value outside
30–120 seconds is clamped back into that range instead of being rejected.

Boundaries are inclusive: `elapsed >= threshold` counts as reached, so a 60
second threshold fires at exactly 60 seconds, not 61.

## Safety properties

- Hints are **never revealed automatically**. The card states what is on offer
  and why; the text appears only after the player taps **Reveal**.
- The **complete answer is never exposed** — the strongest hint is one letter,
  and only for answers of five letters or more.
- The clue is **never printed twice**. It is already at the top of the Play
  screen, so a clue hint points back at it instead of repeating it.
- Each hint kind is offered **once per session of an attempt**. Revealing or
  declining it removes the offer, so repeated wrong guesses cannot re-raise the
  same hint or inflate the stored count. A restart is the one exception, and it
  cannot inflate the count either — see [Limitations](#limitations).

## Persistence

An accepted hint increments the attempt's `hints_used` column through the
existing `AttemptRepository` (no schema change — the column has existed since
Step 3). Resetting an attempt returns the count to zero.

Reopening an unfinished attempt restores the stored count, clamped to the
0–2 range that the two hint kinds make possible, so a corrupt or negative
value cannot carry forward. Within a session the count is the number of
distinct kinds revealed; across a restart the restored count acts as a floor:

    hintsUsed = max(restoredCount, distinctKindsRevealedThisSession)

The column stores a count, never which kinds produced it, so this is the
strongest guarantee available without a schema change. It means a hint can
never be counted twice — the known cost is described under
[Limitations](#limitations).

## Baseline

`suggestBaselineHint` is the fixed-rule comparison: offer the clue after the
first wrong guess, ignoring elapsed time, the saved threshold and the answer
length. It is the simplest defensible policy and makes the value of HintCoach's
extra conditions measurable.

## Evaluation

> **Status: expected outcomes, not executed.** The Step 9 instructions
> prohibited running Flutter commands, so `flutter test` has not been run
> against these cases. Every result below is the outcome the implemented rules
> are expected to produce, derived from the code, and each has a corresponding
> test in `test/hint_coach_test.dart` awaiting execution. The earlier steps'
> suites were executed and passed; this step's have not.

Threshold is 60 seconds unless stated otherwise.

| # | Case | Inputs | HintCoach (expected) | Baseline (expected) | Why it matters |
| --- | --- | --- | --- | --- | --- |
| 1 | Normal gameplay | 1 wrong guess, 10 s, 7 letters | Clue | Clue | Both agree on the common case |
| 1b | Normal gameplay, escalated | 2 wrong guesses, 61 s, 7 letters | First letter | Clue | HintCoach escalates when the player is genuinely stuck |
| 2 | No previous history | 0 wrong guesses, 0 s | No hint | No hint | Neither nags a player who has just started |
| 2b | Slow but accurate | 0 wrong guesses, 60 s, 7 letters | Clue | No hint | Baseline cannot help a player who is stuck without guessing |
| 3 | Invalid input | −3 wrong guesses, 90 s, 7 letters | No hint, with an on-screen explanation | No hint | Corrupt counters cannot unlock a hint |
| 3b | Invalid input | 2 wrong guesses, −1 s, 7 letters | No hint, with an on-screen explanation | Clue | A broken clock stops hints instead of weakening them |
| 3c | Invalid input | 5 wrong guesses, 300 s, 0 letters | No hint, with an on-screen explanation | Clue | There is no answer to hint at |
| 3d | Out-of-range setting | 2 wrong guesses, 120 s, threshold 9999 | First letter (threshold clamped to 120) | Clue | A stale setting cannot suppress hints forever |
| 4 | Threshold boundary | 0 wrong guesses, 59 s then 60 s | No hint, then clue | No hint both times | The boundary is exact and inclusive |
| 4b | Threshold boundary, escalated | 2 wrong guesses, 59 s then 60 s | Clue, then first letter | Clue both times | Escalation waits for the clock |
| 5 | Four-letter counterexample | 4 wrong guesses, 300 s, 4 letters | Clue | Clue | One letter of a four-letter answer gives away too much |
| 5b | Five-letter boundary | 2 wrong guesses, 60 s, 5 letters | First letter | Clue | Five letters is the shortest answer that qualifies |

### Expected comparison

- **Agreement:** cases 1, 2, 5 — HintCoach matches the baseline where the
  baseline is already right.
- **HintCoach helps more:** cases 2b, 4 (second half) — a player who is stuck
  without guessing wrong gets the clue once the threshold passes; the baseline
  offers nothing at all.
- **HintCoach helps better:** cases 1b, 4b, 5b — the first letter arrives when
  wrong guesses *and* time both say the player is stuck, which the baseline
  cannot express.
- **HintCoach is more conservative:** case 5 and the first halves of 4 and 4b —
  it withholds the letter for short answers and before the threshold, where the
  baseline would already be offering its only hint.

### Trade-offs

- The threshold is player-controlled, so two players can see different hints for
  the same attempt. That is intentional and visible in Settings.
- The rules use counters only. They do not look at guess similarity or category
  history, which keeps them explainable and cheap to evaluate every second.

## Limitations

**Restored hints can be offered again.** `attempts.hints_used` stores a count,
not which kinds were revealed. After a restart HintCoach therefore cannot tell
whether the restored hint was the clue or the first letter, and a kind the
player has already seen may be offered once more. Nothing is revealed without
the player accepting it, so this costs a redundant offer, not a leak.

**A second kind after a restart is not added to the count.** Because the
restored count acts as a floor, a player who revealed the clue before a restart
and the first letter after it is recorded as having used one hint, not two. The
alternative — adding the two together — would count the same hint twice for a
player who simply re-reveals what they already saw. Under-counting was chosen
over double-counting, and the total can never exceed the two kinds that exist.

Recording the kinds exactly would need a second column or an encoded value in
`hints_used`, both of which are schema or semantic changes that Step 9 rules
out.
