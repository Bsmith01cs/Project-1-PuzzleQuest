# PuzzleQuest — Project Report

**Author:** Brian Smith
**Repository:** https://github.com/Bsmith01cs/Project-1-PuzzleQuest
**Report date:** 31 October 2026
**Toolchain:** Flutter 3.47.5 (stable), Dart ^3.13.4, Android SDK 36.0.0

## 1. Overview

PuzzleQuest is an offline Android word-scramble game. The player keeps a
catalog of puzzles, plays them against a clock, and reviews a saved history of
every attempt. An on-device rule engine, HintCoach, decides when a hint has been
earned and which one to offer.

The app has no network code. Every byte it stores is local: puzzles and attempts
in SQLite, three preferences in `SharedPreferences`.

## 2. Implementation

Built in ten steps, one commit each.

| Step | Commit | Delivered |
| --- | --- | --- |
| 1 | `f03aff7` | Flutter project scaffold |
| 2 | `1479bfd` | Five-screen navigation shell |
| 3 | `6d9b121` | Puzzle catalog and editor CRUD |
| 4 | `eea1ad3` | SQLite models, schema and repositories |
| 5 | `9a89797` | Word-scramble gameplay |
| 6 | `258eb5e` | Attempt persistence and restart recovery |
| 7 | `7d30ca4` | History and insights with attempt notes |
| 8 | `7c2ba6b` | Theme, motion and hint settings |
| 9 | `397f61a`, `59b6952` | HintCoach, and a dialog-controller fix found verifying it |
| 10 | `21b8211` | Hint-kind persistence, accessibility fixes, integration tests |

**Design decisions worth naming:**

- **No state-management package.** `ChangeNotifier` + `ListenableBuilder` for
  settings; screens own the rest. The app is small enough that a package would
  add indirection without removing any.
- **Repositories hold all SQL.** Screens never see a `Database`. Each screen
  takes its repositories as optional constructor parameters, which is the only
  seam the tests need — no mocking package.
- **Writes are serialized** through a `Future` chain, so an attempt's insert
  always precedes its updates. This is what guarantees one row per attempt
  however fast the controls are tapped.
- **Hints are pure functions.** `lib/hints/hint_coach.dart` has no widgets and
  no I/O, so it is cheap to evaluate every second and trivial to test.
- **Foreign keys are enforced.** `PRAGMA foreign_keys = ON` in `onConfigure`,
  with `ON DELETE CASCADE` from attempts to puzzles.

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full structure and
[AI_FEATURE.md](AI_FEATURE.md) for HintCoach's rules and evaluation.

## 3. Testing

Executed 31 October 2026 on Flutter 3.47.5:

```
flutter analyze  →  No issues found!
flutter test     →  All tests passed!  (192 tests, 0 failed)
```

| Suite | Tests | Covers |
| --- | --- | --- |
| `hint_coach_test.dart` | 54 | HintCoach rules, boundaries, invalid input, baseline, hint persistence across restarts |
| `history_screen_test.dart` | 32 | Filtering, statistics, note validation, deletion |
| `play_screen_test.dart` | 31 | Scrambling, the game state machine, persistence, lifecycle |
| `settings_test.dart` | 25 | Defaults, persistence, restoration, failure handling, theming |
| `puzzle_validation_test.dart` | 16 | Answer, clue and category rules |
| `widget_test.dart` | 15 | Navigation, catalog CRUD, editor |
| `models_test.dart` | 7 | Row serialization both ways |
| `accessibility_test.dart` | 6 | Guideline checks across all five screens |
| `integration_flow_test.dart` | 6 | End-to-end user flows |

**Emulator verification** (Medium Phone AVD, Android 17 / API 37, debug build,
airplane mode on for the database work):

| Check | Result |
| --- | --- |
| Full gameplay: start, guess, hint, pause, resume, reset, solve | As specified |
| Attempt row written and updated in place | One row per attempt |
| Close the app mid-puzzle and reopen | Resumes paused, clock unchanged, guesses and last guess restored |
| A revealed hint after a restart | Shown again, never re-offered, counted once |
| Upgrade from a version 1 database | `user_version` 1 → 2, `hint_kinds` added, all rows and notes preserved |
| Delete a puzzle holding two attempts | Both attempt rows removed by cascade |
| History, statistics and notes offline | Unchanged |
| Portrait and landscape | Both render without overflow |
| Release APK install and launch | Installs over the debug build, launches, existing data intact |

**Defects found and fixed during verification:**

1. A `TextEditingController` disposed while its dialog was still animating away,
   which failed eight History tests (Step 9 verification).
2. Gameplay saves wiped a note written in History — `_save()` omitted
   `userNote` (Step 10).
3. The catalog header overflowed at double text size (Step 10).
4. HintCoach re-offered and mis-counted a hint after a restart, fixed with the
   `hint_kinds` column and its migration (Step 10).

## 4. Accessibility

Verified by executed tests rather than inspection, using Flutter's own
`meetsGuideline` matchers across all five screens with content on screen:

| Check | Result |
| --- | --- |
| 48dp touch targets (`androidTapTargetGuideline`) | Passes on all five |
| Labelled tap targets (`labeledTapTargetGuideline`) | Passes on all five |
| Text contrast (`textContrastGuideline`) | Passes in light and dark |
| Double text size | No overflow on any screen |
| Landscape (800×400) | No overflow on any screen |
| Keyboard | Guess field takes focus, Enter submits, Tab traverses |
| Reduced motion | Page transitions and animations disabled when the setting is on |

Labels added for screen-reader users: the scrambled letters announce as
"Scrambled letters: R, F, T, L, E, T, U" rather than running together; the hint
threshold slider announces seconds instead of a percentage; catalog row actions
name the puzzle by its clue, never its answer.

## 5. Limitations

- **Real SQLite is not exercised in `flutter test`.** `sqflite` has no Dart VM
  implementation, and `sqflite_common_ffi` would be a new dependency. The schema,
  migration and cascade are verified on an emulator instead.
- **Attempts stored before database version 2** carry a hint count without the
  kinds behind it, so for those rows only, a hint already seen may be offered
  once more and a second kind is not added to the count. Rows written since the
  upgrade are exact.
- **One emulator.** The second available AVD (Pixel 7) could not take the
  install: its data partition was 91% full and the install failed with
  `INSTALL_FAILED_INSUFFICIENT_STORAGE`. Clearing it would have removed other
  coursework apps. No physical device was tested.
- **No peer or user testing** has been carried out. Nothing in this repository
  reports how anyone other than the developer experienced the app.
- **Not verified by automated test:** TalkBack with a real screen reader, and
  system font-scale settings beyond the programmatic 2× check.
- **Release signing** uses the Flutter template's debug key. The APK installs
  and runs but is not signed for distribution.
- Minor carry-overs: an unreachable `puzzle == null` placeholder branch in
  `PlayScreen`, and `history_screen.dart` importing `formatElapsed` from
  `play_screen.dart`.

## 6. Outcomes

Every requirement set in Steps 1–10 is implemented and verified:

- Five screens with working navigation.
- Full CRUD on puzzles, with validation and confirmation dialogs.
- SQLite persistence with foreign keys, cascade deletion and a versioned
  migration that preserves existing records.
- Attempt persistence and restart recovery, with the clock never counting time
  the app spent closed.
- History with filtering, statistics, notes and deletion.
- Three persisted settings restored at launch.
- HintCoach: transparent local rules, an optional hint with an explanation,
  never auto-revealed, never the full answer, usage persisted, compared against
  a fixed-rule baseline.
- Accessibility checks passing across all five screens.
- `flutter analyze` clean, 192 tests passing, debug and release APKs building,
  the release APK installing and launching on an emulator.

What is genuinely outstanding is listed in section 5 — chiefly that no one but
the developer has used the app.
