# LiftLog — iOS workout logger

A small SwiftUI app that logs workouts into `training.md` (this repo's format) and
pushes each entry straight to GitHub via the Contents API. No server, no database —
your `training.md` stays the single source of truth, human-readable and diff-friendly.

## What it does
- **Log** tab: pick a date, pick/type an exercise (with autocomplete from your history
  and a "last time: 80x8 80x8 80x8" hint), add sets, tap **Save & push**.
- **History** tab: browse everything in `training.md`, pull-to-refresh from GitHub.
- **Settings** tab: repo owner/name/path/branch + your token (stored in the Keychain).

## One-time setup in Xcode
1. **File ▸ New ▸ Project ▸ iOS ▸ App.**
   - Product Name: `LiftLog`
   - Interface: **SwiftUI**, Language: **Swift**
   - Save it anywhere (e.g. inside `ios/`).
2. Xcode generates `LiftLogApp.swift` and `ContentView.swift`. **Delete both**
   (Move to Trash) — this repo provides its own. (This clears the
   "'main' attribute cannot be used in a module that contains top-level code" error.)
3. Drag the files from `ios/LiftLog/` (this folder's `.swift` files **and** the
   `Views/` folder) into the Xcode project navigator. Check **"Copy items if needed"**
   is *un*checked and the LiftLog target is ticked, so they reference these files in git.
4. Build & run on your iPhone (select your device, then ▶). Free provisioning lets it
   run for 7 days per rebuild; a $99/yr Apple Developer account keeps it installed.

## Create the GitHub token
1. GitHub ▸ Settings ▸ Developer settings ▸ **Fine-grained personal access tokens** ▸
   Generate new token.
2. **Repository access:** Only select repositories → this repo.
3. **Permissions:** Repository permissions ▸ **Contents: Read and write**.
4. Copy the token into the app's **Settings** tab. Fill in owner, repo (`training`),
   path (`training.md`), branch (`main`), then **Test connection / reload**.

## Notes
- The token is stored in the iOS Keychain, never in UserDefaults or source.
- Each save re-fetches the file SHA before writing, so concurrent edits won't clobber.
- Saving an exercise that already exists for that date **replaces** its line (edit-friendly).
