<p align="center">
  <img src="LiftLog/Assets.xcassets/AppIcon.appiconset/icon-1024.png" width="120" alt="LiftLog icon">
</p>

# LiftLog — iOS workout logger

A native SwiftUI app that logs workouts into a plain-text `training.md` and
pushes each entry straight to a GitHub repo via the Contents API. No server, no
database — the text file stays the single source of truth, human-readable and
diff-friendly.

Point the app at any repo you control from the **Settings** tab (GitHub owner /
repo / path / branch + a fine-grained token). It reads and writes one file, so
your training history is portable, greppable, and outlives the app itself.

<p align="center">
  <img src="docs/session.png" width="300" alt="LiftLog Session screen — bold, gym-friendly logging UI">
</p>

## `training.md` format

One line per exercise per day; a blank line separates dates:

```
2026-08-30 deadlift 82.5x8 82.5x8 82.5x8
2026-08-30 chin-ups bwx6 bwx6 bw+5x6
```

- **Date** — ISO `YYYY-MM-DD`. Exercises sharing a date form one session.
- **Exercise** — lowercase `kebab-case` (consistent spelling groups sessions for trends).
- **Sets** — space-separated `weightxreps` tokens: `82.5x8` (kg × reps),
  `bwx6` (bodyweight × reps), `bw+5x8` (bodyweight **+ 5 kg** × reps).

## Why plain text? (great for LLMs)

Because the log is just a small Markdown file, there's nothing to export and no
schema to reverse-engineer — you can hand the whole thing to an LLM and ask real
questions about your training:

> _"Am I actually progressing on squat over the last two months, or just adding
> volume?"_
> _"Plan next week's lower-body session at ~RPE 8 based on my recent top sets."_
> _"Which lifts have stalled the longest?"_

The format **is** the data: greppable, diffable, and directly readable by any
model. Your training history stays portable and future-proof — usable by tools
that don't exist yet, no database migration required.

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
- **History** — browse every session; pull to refresh from GitHub. Swipe any
  exercise to delete it (with a confirm), which is pushed like any other edit.
- **Trends** — per-lift progression chart (top-set weight by default; Est. 1RM as a
  secondary metric; added-load or max-reps for bodyweight lifts) with short-term
  (3-week) and long-term (all-time) change tiles.
- **Settings** — GitHub owner / repo / path / branch + a fine-grained token.

## Tests
The pure-logic layer (parsing, serialization, analytics) lives in `LiftLog/Core`
and is Foundation-only, so it builds and runs as a Swift package with no
simulator:

```
swift test
```

The same files compile into the iOS target via Xcode's synchronized folder, so
`swift test` exercises the exact production code. Coverage: `training.md`
parse/serialize round-trips, the `bw` / `bw+5` bodyweight tokens, malformed-line
handling, and the Trends analytics (top-set, Est. 1RM, added-load series, change
tiles).

## GitHub token
Create a **fine-grained personal access token** scoped to only this repo with
**Contents: Read and write**, and paste it into the Settings tab. It's stored in
the iOS Keychain, never in source or UserDefaults.

## How saves stay safe
Each save **fetches the current `training.md`, merges the one edited exercise into
it, then writes** — it never serializes stale in-memory state, so a save can't drop
history that exists on GitHub. The fetch bypasses the URL cache and retries on
GitHub 409 conflicts to avoid stale-SHA errors.

## Offline
Gyms eat signal, so writes are offline-first. If a save (or delete) can't reach
GitHub, it's **queued locally and applied optimistically** — the entry shows up in
the app immediately — and the file's last-known content is cached so History and
Trends still work with no connection. The queue **flushes automatically on the next
successful load or save**, replaying each change through the same safe
merge-on-remote path; you can also see and retry it from **Settings ▸ Waiting to
sync**. The queue survives an app kill (persisted in `UserDefaults`; the token stays
in the Keychain).
