# PuzzleQuest — Submission Checklist

Audited 31 October 2026 against the approved proposal
(`PuzzleQuest_Project1_Proposal_FINAL_2026-10-18.docx`, sections 06–07).

Nothing in this file is assumed. An item is marked complete only where it was
verified in the repository, by an executed command, or on an emulator in this
session.

## Complete

| # | Requirement | Evidence |
| --- | --- | --- |
| 1 | Five-screen Flutter app | `lib/screens/` — Catalog, Editor, Play, History, Settings |
| 2 | Two related SQLite tables with full CRUD | `puzzles` and `attempts`, `lib/repositories/` |
| 3 | `PRAGMA foreign_keys = ON` and `ON DELETE CASCADE` | `database_helper.dart`; cascade confirmed on the emulator |
| 4 | Restart recovery, timer suspended on background | `play_screen.dart`; confirmed on the emulator |
| 5 | SharedPreferences settings restored at launch | `settings_controller.dart`; 25 tests |
| 6 | HintCoach: local rules, explanation, Reveal / Not now, never auto-revealed, never the full answer | `lib/hints/hint_coach.dart`, `AI_FEATURE.md` |
| 7 | Fixed-rule baseline and five reproducible evaluation cases | `AI_FEATURE.md`; all 14 table rows re-derived from the live rules |
| 8 | Accessibility: semantics, 48dp, scalable text, contrast, portrait/landscape, keyboard, reduced motion | `test/accessibility_test.dart`, 6 guideline tests |
| 9 | `flutter analyze` clean | No issues found |
| 10 | `flutter test` | 192 tests, 0 failed |
| 11 | Release APK built, installed and launched | `app-release.apk`, verified on Android 17 (API 37) |
| 12 | README | `README.md` |
| 13 | ARCHITECTURE.md | `ARCHITECTURE.md` |
| 14 | AI_FEATURE.md | `AI_FEATURE.md` |
| 15 | Project report | `PROJECT_REPORT.md` |
| 16 | Demo outline (20–25 min) | `DEMO_OUTLINE.md` — the outline, not the recording |
| 17 | GitHub repository, all work pushed | `origin/main` matches local at `0faea44` |
| 18 | Submission ZIP | `submission/PuzzleQuest_Brian_Smith_Project1_2026-10-31.zip` |

## Missing — no evidence found on this machine

| # | Requirement | Status |
| --- | --- | --- |
| 19 | **20+ genuine commits** | **12 commits.** Shortfall of 8 |
| 20 | **Feature branches with review/test documentation** | All 12 commits are on `main`; no branches, no PRs |
| 21 | **Dated ClickUp snapshots for Oct 21, 24 and 28** | None found. Only the Oct 18 planning snapshot, which is inside the proposal's Appendix A |
| 22 | **`Kanban_Contribution_Evidence.pdf`** | Does not exist anywhere on this machine |
| 23 | **Task → code/PR → test trace** | Not assembled |
| 24 | **20–25 minute demo recording** | No video file found |
| 25 | **Peer usability observation and a verified design change** | Not carried out. `AI_FEATURE.md` and `PROJECT_REPORT.md` both state this plainly |
| 26 | **Two-device / two-emulator offline restart test** | One emulator only. The second AVD (Pixel 7) failed to install with `INSTALL_FAILED_INSUFFICIENT_STORAGE` at 91% full |
| 27 | **Signed participation acknowledgment** | `PuzzleQuest_Solo_Participation_Statement_TO_SIGN.docx` is in `~/Downloads`, unsigned |
| 28 | **Written evidence of the professor's title / solo approval** | The proposal records it as student-reported; no written approval file found |

## Requires you, not the code

| # | Action |
| --- | --- |
| 29 | Capture the current ClickUp board, dated, and build `Kanban_Contribution_Evidence.pdf` from the Oct 18 snapshot plus whatever later ones you have |
| 30 | Record the 20–25 minute demo using `DEMO_OUTLINE.md` |
| 31 | Run the peer usability observation, record the feedback and any design change, and add it to `AI_FEATURE.md` |
| 32 | Free space on the Pixel 7 AVD (or use another device) and repeat the offline restart test, then record the actual result |
| 33 | Sign the participation statement and export it as a readable PDF |
| 34 | Confirm the instructor can open the ClickUp list: `https://app.clickup.com/90141779054/v/li/901422387404` |
| 35 | Upload to iCollege and verify the receipt |

## Notes on the schedule

The proposal's milestone plan ran Oct 18–28; the repository's first
implementation commit is dated 23 October and the last is 31 October. The Oct 28
submission date in the plan has passed. That is a factual discrepancy to resolve
with the instructor, not something the code can fix.

## About the commit shortfall

Twelve commits exist, one per development step, each with a conventional,
descriptive message. Reaching 20 by splitting or rewriting what is already
committed would mean rewriting history and manufacturing commits, which the
assignment's "genuine commits" wording rules out. Any remaining real work —
the items above, screenshots, a signed statement, peer-test findings — will add
genuine commits as it lands.
