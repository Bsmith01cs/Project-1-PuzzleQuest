# Architecture

PuzzleQuest is a single-module Flutter app with no state-management package and
no service layer. Screens own their state, repositories own the database, and a
single `ChangeNotifier` carries settings. Everything runs on the device.

```
lib/
  main.dart                      app entry, theme, reduced-motion wiring
  database/database_helper.dart  opens the SQLite file, creates and upgrades it
  models/                        Puzzle, Attempt — row mirrors with to/fromMap
  repositories/                  PuzzleRepository, AttemptRepository — all SQL
  screens/                       the five screens plus the navigation shell
  settings/settings_controller.dart  SharedPreferences-backed app settings
  hints/hint_coach.dart          the HintCoach rules — pure functions, no I/O
```

## Navigation

Five screens. Three are tabs inside a shell; two are pushed routes.

```
PuzzleQuestApp (MaterialApp)
└── HomeShell — Scaffold + NavigationBar + IndexedStack
    ├── [0] CatalogScreen ──push──> EditorScreen   (create / edit)
    │                    └─push──> PlayScreen      (gameplay)
    ├── [1] HistoryScreen
    └── [2] SettingsScreen
```

- `IndexedStack` keeps all three tabs alive, so switching tabs does not discard
  a filter or a scroll position.
- History is the exception: it must show attempts finished since it was last
  built, so `HomeShell` gives it a `ValueKey` that increments whenever History
  is selected. The screen remounts and reloads. The cost is that its status
  filter resets, which is the intended trade.
- `EditorScreen` and `PlayScreen` are `Navigator.push`ed from the catalog, so
  they get a back arrow and the tab bar stays behind them. The editor returns
  `true` when it saved, which tells the catalog to reload.
- Reduced motion is applied at the `MaterialApp` level: a `PageTransitionsTheme`
  of no-op builders for all six platforms, plus a `MediaQuery` override setting
  `disableAnimations`.

## SQLite

One database file, `puzzle_quest.db`, opened through `DatabaseHelper.instance`.
`PRAGMA foreign_keys = ON` is issued in `onConfigure`, so it applies to every
connection — SQLite otherwise ignores foreign keys entirely.

### Schema (version 2)

```sql
CREATE TABLE puzzles (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  answer     TEXT NOT NULL,
  clue       TEXT NOT NULL,
  category   TEXT NOT NULL,
  difficulty INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE attempts (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  puzzle_id       INTEGER NOT NULL,
  status          TEXT NOT NULL,
  wrong_guesses   INTEGER NOT NULL DEFAULT 0,
  hints_used      INTEGER NOT NULL DEFAULT 0,
  hint_kinds      TEXT,
  elapsed_seconds INTEGER NOT NULL DEFAULT 0,
  last_guess      TEXT,
  user_note       TEXT,
  started_at      TEXT NOT NULL,
  finished_at     TEXT,
  FOREIGN KEY (puzzle_id) REFERENCES puzzles (id) ON DELETE CASCADE
);

CREATE INDEX idx_attempts_puzzle_id ON attempts (puzzle_id);
```

### Relationships

One puzzle has many attempts. `ON DELETE CASCADE` means deleting a puzzle
deletes its attempts in the same statement — the repository never touches the
`attempts` table to do it. The index on `puzzle_id` serves both the cascade and
`findByPuzzle`.

Timestamps are ISO-8601 UTC strings. `finished_at IS NULL` is what makes an
attempt unfinished, and is how restart recovery finds the row to restore.

### Migrations

`_version = 2`. `onCreate` builds the schema above; `onUpgrade` brings older
files forward and only ever adds:

| From → to | Statement |
| --- | --- |
| 1 → 2 | `ALTER TABLE attempts ADD COLUMN hint_kinds TEXT` |

No row is rewritten or dropped, so stored puzzles, attempts, notes and counts
survive an upgrade. Rows written before version 2 read `hint_kinds` back as
`NULL`, which the app treats as "kinds unknown".

### CRUD

All SQL lives in two repositories. Both take an optional `DatabaseHelper`, which
is the seam the tests use.

| `PuzzleRepository` | |
| --- | --- |
| `seedStarterPuzzlesOnce()` | Inserts three starter puzzles the first time only, guarded by a `SharedPreferences` flag rather than by row count, so a user who deletes them does not get them back |
| `findAll()` | Every puzzle, newest first |
| `insert` / `update` / `delete` | By `id`; delete cascades to attempts |

| `AttemptRepository` | |
| --- | --- |
| `insert` / `update` / `delete` | `update` uses `ConflictAlgorithm.abort` |
| `findAll()` | Every attempt, `started_at DESC` — the History list |
| `findByPuzzle(puzzleId)` | Attempts for one puzzle |
| `findLatestUnfinished(puzzleId)` | The newest row with `finished_at IS NULL` and a status that is not `solved` — restart recovery |
| `findById(id)` | A single attempt |
| `updateNote(id, note)` | Writes `user_note` alone, so a note cannot disturb gameplay columns |

Statuses are `in_progress`, `paused` and `solved`, declared as constants on
`Attempt` rather than written as strings at each call site.

## Settings

`SettingsController extends ChangeNotifier`, backed by `SharedPreferences`.

| Setting | Key | Range / default |
| --- | --- | --- |
| Dark theme | `settings_dark_theme` | off |
| Reduced motion | `settings_reduced_motion` | off |
| Hint threshold | `settings_hint_threshold_seconds` | 30–120 s, default 60 |

- `main()` awaits `load()` before `runApp`, so the app never flashes the wrong
  theme at launch.
- Writes are optimistic: the in-memory value changes and listeners are notified
  first, then the write is attempted. A failed read or write sets
  `preferencesUnavailable`, the Settings screen says the settings will only last
  until the app closes, and the app keeps working.
- A threshold outside 30–120 is clamped on read, so a corrupted stored value
  cannot disable hints.
- The controller is created once by `HomeShell` (or injected in tests) and
  passed down. `ListenableBuilder` rebuilds `MaterialApp` and the Settings
  screen; `PlayScreen` reads the threshold from the same instance.

## Data flow

### Gameplay and persistence

`PlayScreen` holds the game state (`ready` → `running` ⇄ `paused` → `solved`), a
one-second `Timer.periodic`, and the attempt's id once it has one.

```
open puzzle
  └─ findLatestUnfinished(puzzleId)
       ├─ row found → restore guesses, elapsed, last guess, hint kinds, note
       │              and enter `paused` (the clock must not count time away)
       └─ none      → start fresh in `ready`

Start / guess / pause / resume / reset / solve
  └─ _enqueueSave()
       └─ insert (first time, keeps the new id) or update
```

Two details make this reliable:

- **Writes are serialized** through a `Future` chain, so the insert always wins
  the race against the updates that follow it. That is what guarantees one row
  per attempt no matter how fast the controls are tapped.
- **Lifecycle** — `WidgetsBindingObserver.didChangeAppLifecycleState` pauses a
  running game as soon as the app leaves the foreground, so backgrounded time is
  never counted.
- A database failure is caught, shown as a quiet line on the screen, and
  gameplay continues unsaved rather than crashing.

Solving sets `finished_at`, which takes the attempt out of restart recovery.
**Reset** on a solved attempt keeps that row as history and opens a new one on
the next Start; reset on an unfinished attempt reuses the same row.

### HintCoach

The rules are pure functions with no widgets and no I/O, which is why they are
cheap to call on every rebuild and easy to test.

```
PlayScreen (every second, and after every guess)
  ├─ validateHintInputs(wrongGuesses, elapsedSeconds, answerLength)
  │    └─ invalid → no offer, the reason is shown on screen
  └─ suggestHint(wrongGuesses, elapsedSeconds, thresholdSeconds, answerLength)
       │     threshold ← SettingsController ← SharedPreferences
       └─ HintSuggestion(kind, explanation) or null

offer card → player taps Reveal
  └─ kind added to the revealed set
       ├─ hintText(kind, answer, clue, clueVisible) rendered
       └─ _enqueueSave() → attempts.hints_used + attempts.hint_kinds
```

Reopening the attempt decodes `hint_kinds` back into the revealed set, so a hint
already accepted is shown again but never offered — or counted — twice. The
rules themselves are documented in [AI_FEATURE.md](AI_FEATURE.md).

## Testing seams

No mocking package is used. Every screen takes its repositories and settings
controller as optional constructor parameters and falls back to the real ones,
so a test passes an in-memory fake and the production path is unchanged. The
end-to-end flow test backs both repositories with a single fake store, which is
how a puzzle created on the catalog is the same row History later shows.
