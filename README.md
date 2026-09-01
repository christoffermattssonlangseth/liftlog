# LiftLog — iOS workout logger

A native SwiftUI app that logs workouts into `../training.md` (this repo's format)
and pushes each entry straight to GitHub via the Contents API. No server, no
database — `training.md` stays the single source of truth, human-readable and
diff-friendly.

## Open & run
- Open **`LiftLog/LiftLog.xcodeproj`** in Xcode.
- Source lives in `LiftLog/LiftLog/` (an Xcode 16 synchronized folder, so files
  in it are part of the target automatically — just add new files there).
- Select your iPhone as the run destination and press ▶. Free provisioning runs
  it for 7 days per rebuild; a paid Apple Developer account keeps it installed.
- First run: enable **Developer Mode** on the phone (Settings ▸ Privacy & Security)
  and **Trust** the developer (Settings ▸ General ▸ VPN & Device Management).

## Tabs
- **Session** — pick a date, choose an exercise (searchable list + your history,
  or type a new name), enter weight/reps from the keyboard, and "Finish exercise"
  to add it to the day. A live "Today's Session" list shows the workout building up.
- **History** — browse every session; pull to refresh from GitHub.
- **Trends** — per-lift progression chart (top-set weight by default; Est. 1RM as a
  secondary metric; max-reps for bodyweight lifts) with short-term (3-week) and
  long-term (all-time) change tiles.
- **Settings** — GitHub owner / repo / path / branch + a fine-grained token.

## GitHub token
Create a **fine-grained personal access token** scoped to only this repo with
**Contents: Read and write**, and paste it into the Settings tab. It's stored in
the iOS Keychain, never in source or UserDefaults.

## How saves stay safe
Each save **fetches the current `training.md`, merges the one edited exercise into
it, then writes** — it never serializes stale in-memory state, so a save can't drop
history that exists on GitHub. The fetch bypasses the URL cache and retries on
GitHub 409 conflicts to avoid stale-SHA errors.
