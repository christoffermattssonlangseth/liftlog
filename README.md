# LiftLog — iOS workout logger

A native SwiftUI app that logs workouts into a plain-text `training.md` and
pushes each entry straight to GitHub via the Contents API. No server, no
database — `training.md` stays the single source of truth, human-readable and
diff-friendly. The log lives in its own repo
([christoffermattssonlangseth/training.md](https://github.com/christoffermattssonlangseth/training.md));
point the app at it from the **Settings** tab.

## Open & run
- Open **`LiftLog.xcodeproj`** in Xcode.
- Source lives in `LiftLog/` (an Xcode 16 synchronized folder, so files in it
  are part of the target automatically — just add new files there).
- Select your iPhone as the run destination and press ▶. Free provisioning runs
  it for 7 days per rebuild; a paid Apple Developer account keeps it installed.
- First run: enable **Developer Mode** on the phone (Settings ▸ Privacy & Security)
  and **Trust** the developer (Settings ▸ General ▸ VPN & Device Management).

## Tabs
- **Session** — pick a date, choose an exercise (searchable list + your history,
  or type a new name), enter weight/reps on the big number pads, and "Finish
  exercise" to add it to the day. A live "Today's Session" list shows the workout
  building up, and a **rest timer** starts counting up each time you add a set.
  Bold / gym-friendly styling: strong accent, large touch targets, chunky buttons.
- **History** — browse every session; pull to refresh from GitHub.
- **Trends** — per-lift progression chart (top-set weight by default; Est. 1RM as a
  secondary metric; added-load or max-reps for bodyweight lifts) with short-term
  (3-week) and long-term (all-time) change tiles.
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
