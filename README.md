# PuzzleQuest

An offline word-scramble game for Android, built with Flutter. Puzzles are
yours to create and edit, every attempt is saved to a local SQLite database,
and an on-device rule engine called **HintCoach** decides when a hint has been
earned and which one to offer.

Nothing leaves the device. There is no account, no network call and no
analytics — the app works in airplane mode exactly as it does online.

## Features

- **Puzzle catalog** — create, edit and delete puzzles, filter them by
  difficulty. Three starter puzzles are seeded on first launch.
- **Gameplay** — the answer is scrambled, you guess, and the clock runs while
  you play. Start, pause, resume and reset are all under your control.
- **Attempt persistence** — every attempt is written to SQLite as it happens.
  Close the app mid-puzzle and it reopens paused, with your elapsed time, wrong
  guesses and last guess intact. The clock never counts time while the app is
  closed or backgrounded.
- **History & insights** — every attempt with its status, time, wrong guesses
  and completion date; filters by status; totals, solved count and completion
  rate; a note of up to 140 characters per attempt; per-attempt deletion.
- **HintCoach** — a transparent, local rule system that offers the clue or the
  first letter when the rules say you have earned it. It never reveals a hint by
  itself and never shows the whole answer. See [AI_FEATURE.md](AI_FEATURE.md).
- **Settings** — dark theme, reduced motion, and a hint threshold from 30 to
  120 seconds. All three are saved and restored at launch.
- **Accessibility** — 48dp touch targets, labelled controls, readable contrast
  in both themes, layouts that survive double text size and landscape, and a
  reduced-motion mode that disables page transitions.

## Requirements

| | |
| --- | --- |
| Flutter | 3.47.5 (stable) or newer |
| Dart SDK | ^3.13.4 |
| Target | Android (verified on Android 17 / API 37) |
| Android SDK | 36.0.0 with an emulator or device |

Dependencies, all already in `pubspec.yaml`: `sqflite`, `path`,
`shared_preferences`, `cupertino_icons`, and `flutter_lints` for development.

## Installation

```bash
git clone https://github.com/Bsmith01cs/Project-1-PuzzleQuest.git
```

```bash
cd Project-1-PuzzleQuest && flutter pub get
```

Run it on a connected device or a booted emulator:

```bash
flutter run
```

Or build and install a release APK:

```bash
flutter build apk --release
```

```bash
flutter install --release
```

The built APK is written to `build/app/outputs/flutter-apk/app-release.apk`.

## Usage

1. **Catalog** — the app opens here. Tap **Create Puzzle** to add one: an
   answer of 4–12 letters (letters only, not all the same), a clue of up to 120
   characters, a category of up to 40, and a difficulty. The pencil edits a
   puzzle, the bin deletes it together with its attempt history.
2. **Play** — tap a puzzle to open it, then **Start**. Type a guess and tap
   **Check**. **Pause** stops the clock; **Reset** starts the puzzle over.
   Reopen a puzzle you left unfinished and it resumes paused where you stopped.
3. **Hints** — when the rules are met a card appears explaining why a hint is on
   offer. **Reveal** shows it and records it against the attempt; **Not now**
   dismisses it. Hints are never revealed for you.
4. **History** — the second tab. Filter by status, read your statistics, tap the
   note icon to annotate an attempt, or the bin to delete one.
5. **Settings** — the third tab. Dark theme, reduced motion, and the hint
   threshold slider that HintCoach reads.

## Development

```bash
flutter analyze
```

```bash
flutter test
```

192 tests cover the puzzle rules, gameplay, persistence, restart recovery,
history, settings, HintCoach, accessibility guidelines and an end-to-end user
flow. `sqflite` has no Dart VM implementation, so the tests reach the database
through injected repositories rather than a real file; the schema, its
migration and cascade deletion are verified on an emulator instead.

## Documentation

| Document | Covers |
| --- | --- |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Navigation, SQLite schema, settings, and the data flow through gameplay and HintCoach |
| [AI_FEATURE.md](AI_FEATURE.md) | HintCoach's rules, its fixed-rule baseline, and the evaluation results |
| [PROJECT_REPORT.md](PROJECT_REPORT.md) | What was built, how it was tested, and what is left |
| [DEMO_OUTLINE.md](DEMO_OUTLINE.md) | The 20–25 minute walkthrough |
