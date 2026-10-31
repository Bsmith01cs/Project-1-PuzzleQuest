# PuzzleQuest — Demo Outline (20–25 minutes)

**Format:** live app on an Android emulator, with the IDE and the repository
open in other windows. Timings are cumulative targets, not a script.

## Before you start

- [ ] Emulator booted; release APK installed
      (`flutter install --release`, or `adb install -r build/app/outputs/flutter-apk/app-release.apk`).
- [ ] App opened once so the three starter puzzles are seeded.
- [ ] One **solved** attempt and one **unfinished** attempt already in History,
      so the History tab and restart recovery have something real to show.
- [ ] Airplane mode **on** — it makes the offline claim visible rather than
      asserted.
- [ ] Editor open on `lib/hints/hint_coach.dart` and `lib/database/database_helper.dart`.
- [ ] A terminal in the project directory, ready to run `flutter test`.
- [ ] ClickUp board open in a browser tab.

---

## 1. Introduction — 2 min (0:00–2:00)

- What PuzzleQuest is: an offline word-scramble game where the player owns the
  puzzle set and every attempt is saved.
- Point at the airplane-mode icon: no network, no account, no analytics.
- The one-sentence version of the stack: Flutter, Material 3, SQLite via
  `sqflite`, `SharedPreferences`, no state-management package.

## 2. The five screens — 4 min (2:00–6:00)

Walk the navigation before doing anything with it, so the structure is clear.

1. **Catalog** — the three tabs live in an `IndexedStack`; switching tabs keeps
   each tab's state.
2. **History** — note that this tab *reloads* on every visit, and say why: it
   must show attempts finished since it was last built.
3. **Settings** — three settings, nothing more.
4. Back to Catalog, tap a puzzle → **Play** is a pushed route with a back arrow.
5. Back, tap the pencil → **Editor**, also pushed.

## 3. Puzzle CRUD — 3 min (6:00–9:00)

- **Create:** tap Create Puzzle. Type an invalid answer first (`AB`) to show the
  validation — letters only, 4–12 characters, more than one distinct letter —
  and that Save stays disabled until every field is valid. Then enter a real
  puzzle and save.
- **Read:** the new puzzle appears in the list; answers are never shown on the
  cards.
- **Update:** edit its clue, save, show the list refreshed.
- **Filter:** tap a difficulty chip, show the count change to "1 of 4 puzzles".
- **Delete:** tap the bin, read the dialog aloud — it warns that attempt history
  goes too. Cancel rather than confirm, and keep the puzzle for the next
  section.

## 4. Gameplay — 4 min (9:00–13:00)

- Open a puzzle, tap **Start**, point at the clock.
- Enter a wrong guess: the counter increments, the feedback line appears.
- **Pause** — the clock stops and the letters are hidden. **Resume**.
- Solve it, show the solved card.
- **Play again** — explain that a solved attempt is kept as history and the next
  Start opens a fresh row.

## 5. SQLite persistence and restart recovery — 4 min (13:00–17:00)

This is the part worth taking slowly.

- Open the **unfinished** puzzle prepared beforehand. It comes back **paused**,
  with the elapsed time, wrong guesses and last guess restored, and the banner
  "Resumed your unfinished attempt."
- Say the two guarantees and why they are not accidents:
  - **The clock never counts time the app was closed or backgrounded** —
    the lifecycle observer pauses the game as soon as it leaves the foreground.
  - **One row per attempt** — writes are serialized through a `Future` chain,
    so the insert always precedes the updates that follow it.
- Switch to the IDE, show `database_helper.dart`: the schema, the
  `ON DELETE CASCADE` on `attempts.puzzle_id`, `PRAGMA foreign_keys = ON` in
  `onConfigure`, and the version 2 upgrade that adds `hint_kinds` with a single
  `ALTER TABLE`.
- Back to the app: delete a puzzle that has attempts, then open History and show
  its attempts gone. That is the cascade, not application code.

## 6. HintCoach — 4 min (17:00–21:00)

- **Settings first:** move the hint threshold slider and say that HintCoach
  reads this value.
- Play a puzzle and make one wrong guess. The hint card appears with its
  **explanation** — read it out; the explanation is the point.
- Tap **Not now**, then earn it again, and tap **Reveal**. Show "Hints used 1".
- State the two safety properties plainly: a hint is **never revealed
  automatically**, and the **full answer is never shown** — the strongest hint
  is one letter, and only for answers longer than four.
- Show the restart behaviour: close and reopen the puzzle. The hint already paid
  for is shown again but **not offered again**, and the count stays at 1. That is
  the `hint_kinds` column doing its job.
- Open `hint_coach.dart`: the three rules plus the invalid-input guard, as pure
  functions. Mention the fixed-rule **baseline** (`suggestBaselineHint`) and one
  concrete case where they differ — a player stuck for 60 seconds with no wrong
  guesses gets the clue from HintCoach and nothing from the baseline.

## 7. Testing and quality — 3 min (21:00–24:00)

- Run `flutter test` live. 192 tests, 0 failures.
- Show the suite list and name what each covers; call out
  `integration_flow_test.dart` (a full create → play → solve → review → delete
  flow) and `accessibility_test.dart`.
- Accessibility: 48dp targets, labelled controls, contrast in both themes,
  double text size and landscape — all asserted by Flutter's own
  `meetsGuideline` matchers, not by eye. Demonstrate dark theme and reduced
  motion from Settings.
- Say what is **not** covered, without dressing it up: real SQLite is not
  exercised in `flutter test` because `sqflite` has no Dart VM implementation,
  so the database is verified on the emulator instead; and no peer testing has
  been done.

## 8. Repository and project tracking — 1–2 min (24:00–25:00)

- `git log --oneline`: eleven commits, one per step, conventional messages.
- The four documents: `README.md`, `ARCHITECTURE.md`, `AI_FEATURE.md`,
  `PROJECT_REPORT.md`.
- Switch to the **ClickUp** board and walk the tasks as they actually stand —
  what is done, what is in progress, what is left. Tie two or three cards to the
  commits just shown.
- Close on the limitations from the project report, briefly and without
  apology.

---

## If you run short

Cut section 3 to create-and-delete only, and show the editor's validation from
the test file instead of the UI.

## If you run long

Sections 5 and 6 are the ones that earn the marks. Give back time from 2, 3
and 7.

## Questions to expect

| Question | Short answer |
| --- | --- |
| Why no Provider / Riverpod / Bloc? | One `ChangeNotifier` for settings; screens own the rest. A package would add indirection without removing any. |
| How do you know the clock doesn't drift while backgrounded? | `didChangeAppLifecycleState` pauses the game as soon as the app leaves the foreground, and the paused state is written to SQLite. |
| Why not test the real database? | `sqflite` has no Dart VM implementation, and `sqflite_common_ffi` would be a new dependency. The emulator covers it. |
| Is HintCoach actually AI? | It is a transparent rule system, deliberately. Every decision can be read off four inputs, and it is compared against a fixed-rule baseline in `AI_FEATURE.md`. |
| What happens to a user's data on upgrade? | `onUpgrade` only adds a column. Verified on an emulator: a version 1 database came through with every row and note intact. |
