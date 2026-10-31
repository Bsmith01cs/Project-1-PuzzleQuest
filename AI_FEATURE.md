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
- Each hint kind is offered **once per attempt**, restarts included. Revealing
  or declining it removes the offer, and the kinds revealed are stored with the
  attempt, so reopening a puzzle cannot re-raise a hint the player has already
  seen or inflate the stored count. Declining is not stored: a hint turned down
  with **Not now** is offered again next time the puzzle is opened.

## Persistence

An accepted hint is written to the attempt through the existing
`AttemptRepository`. Two columns carry it:

| Column | Holds |
| --- | --- |
| `attempts.hints_used` | How many hints the player accepted (0–2) |
| `attempts.hint_kinds` | Which ones, as a fixed-order token list (`clue`, `firstLetter`) |

`hint_kinds` was added in **database version 2**. The upgrade is a single
`ALTER TABLE attempts ADD COLUMN hint_kinds TEXT` in `DatabaseHelper`, so every
stored puzzle, attempt, note and count survives it untouched; rows written
before the upgrade simply read back as `NULL`.

Reopening an unfinished attempt restores both: the kinds decide what is already
revealed and therefore never offered again, and the count is restored clamped to
the 0–2 range the two hint kinds make possible, so a corrupt or negative value
cannot carry forward. A corrupt or unrecognised token list reads as nothing
revealed rather than throwing. The count written back is

    hintsUsed = max(restoredCount, distinctKindsRevealedThisSession)

where the floor only matters for a row stored before `hint_kinds` existed.
Resetting an attempt clears both columns.

## Baseline

`suggestBaselineHint` is the fixed-rule comparison: offer the clue after the
first wrong guess, ignoring elapsed time, the saved threshold and the answer
length. It is the simplest defensible policy and makes the value of HintCoach's
extra conditions measurable.

## Evaluation

> **Status: verified by executed tests (31 October 2026).** Every case below
> has a test in `test/hint_coach_test.dart`, and the whole suite was run with
> `flutter test` on Flutter 3.47.5: **192 tests passed, 0 failed**, with
> `flutter analyze` reporting no issues. The HintCoach file alone contributes
> 54 of those tests. The HintCoach-versus-baseline columns are the rules'
> actual outputs as asserted by those tests, not projections.
>
> **Not verified:** no peer or user testing has been carried out, so no
> observation about how real players experience the hints is recorded here.

Threshold is 60 seconds unless stated otherwise.

| # | Case | Inputs | HintCoach | Baseline | Why it matters |
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

### Comparison

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

### Verified on a device

Run on a Medium Phone AVD, Android 17 (API 37), from the Android debug build,
with the network off (airplane mode) throughout the database checks:

| Check | Result |
| --- | --- |
| One wrong guess offers the clue with its explanation and Reveal / Not now | As specified |
| Reveal shows the hint and the screen reads `Hints used 1` | As specified |
| Stored row after revealing | `hints_used = 1`, `hint_kinds = clue` |
| Reopening the puzzle after closing the app | Resumed paused, clock unchanged at 00:18, wrong guesses and last guess restored, the revealed hint shown again |
| Resuming that restored attempt | No second offer; row still `hints_used = 1`, `hint_kinds = clue` |
| Upgrade from a version 1 database holding two attempts and a note | `user_version` 1 → 2, `hint_kinds` added, all rows and the note preserved |
| Deleting a puzzle with two attempts | Both attempt rows removed by `ON DELETE CASCADE` |
| History, statistics and notes with the network off | Unchanged |

### Trade-offs

- The threshold is player-controlled, so two players can see different hints for
  the same attempt. That is intentional and visible in Settings.
- The rules use counters only. They do not look at guess similarity or category
  history, which keeps them explainable and cheap to evaluate every second.

## Limitations

**Attempts stored before database version 2 name no hint kinds.** A row written
by an earlier build carries a count without the kinds behind it, so for that one
attempt HintCoach still cannot tell whether the hint already seen was the clue
or the first letter. For those rows only, a kind already seen may be offered
once more, and a second kind revealed after the restart is not added to the
count — the restored count acts as a floor instead. Nothing is ever revealed
without the player accepting it, so the cost is a redundant offer, never a leak,
and the total can never exceed the two kinds that exist. Every attempt created
or updated since the upgrade stores its kinds and is exact.

**Device verification covered one emulator.** The migration, cascade deletion,
offline use and restart recovery were exercised on a Medium Phone AVD running
Android 17 (API 37). The second available AVD (Pixel 7) could not be used: its
data partition was 91% full and the install failed with
`INSTALL_FAILED_INSUFFICIENT_STORAGE`, and clearing it would have removed other
coursework apps. No physical device was tested.

**No peer testing.** Nothing in this document reports how anyone other than the
developer experienced the feature.
