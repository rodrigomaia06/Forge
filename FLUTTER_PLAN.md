# Flutter rewrite plan

The plan of record for rewriting Forge from SwiftUI to Flutter. This SwiftUI repo
stays the reference for features and UI. The rewrite is a separate project.

## Objective

Rewrite Forge as a Flutter app, iOS first. Keep the current features and the look.
It is a clean-room rewrite in Dart, not a fork of Iron, so it carries no GPL
obligation to Iron. Released under GPLv3 by choice.

## Principles that carry over

From this repo's `.claude/CLAUDE.md`, unchanged:

- Local first. No server, no accounts, nothing leaves the device unless the user
  deliberately exports it.
- Quiet, direct, native-feeling, fast. No engagement mechanics.
- Data safety first: understandable schema, explicit migrations, no silent
  rewrites of history.
- The human-written language rules apply to all app text, docs, commits, and PRs.

## Decisions already made

- Shared Dart code between a future iOS build (iOS styled) and Android build
  (Material). Build iOS only for now. Android comes later, as a separate Material
  UI on the same shared core.
- Persistence designed fresh, with clean names, not a copy of the current Core
  Data model.
- No migration for real users. There are none yet. The maintainer hands over the
  current Forge database once; it is transformed into the new schema.
- "Shared backend" means shared code between the apps, never a network server.

## Stack

- Data: `drift` (SQLite, type safe, real migrations). Fits the relational shape
  (plan, routine, exercise, set) and allows a clean schema from the start.
- State: `riverpod`.
- Navigation: `go_router`.
- Design: a custom Forge design system (dark tokens, the set table, the cards),
  not stock widgets, so it matches the current look. Cupertino controls only where
  they are genuinely native.
- Charts: `fl_chart`.
- Notifications and rest timer: `flutter_local_notifications`, with a
  background-safe timer approach (store the end time, never rely on an in-process
  timer surviving suspension).
- Live Activity and Dynamic Island cannot be pure Flutter. They need a small
  native iOS Swift extension (ActivityKit and WidgetKit), bridged with
  `live_activities`. This is the one place native Swift remains.

## Environment setup (Debian DistroBox)

```bash
sudo apt update && sudo apt install -y curl git unzip xz-utils zip libglu1-mesa \
  clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev
git clone https://github.com/flutter/flutter.git -b stable ~/flutter
echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.bashrc && source ~/.bashrc
flutter config --enable-linux-desktop --enable-web
flutter doctor
```

The Linux desktop and web targets let the assistant run and screenshot the UI
directly, which is the main reason for the rewrite. Android emulators need KVM and
often fail in a container, so leave Android until later. iOS release builds still
need a macOS runner. Codemagic has a Flutter friendly free tier, so no Mac is
needed for that.

## First steps in the new project

1. `flutter doctor`, then scaffold so it runs as a Linux desktop or web build.
2. Build the Forge design system (theme, typography, colors, the set table, the
   card, the segmented control, the number field).
3. Define the drift schema, informed by the current model but named cleanly.
4. Import the maintainer's current database once into the new schema.

## Feature parity target

- Live workout as a scroll of exercise cards, each with its set table inline.
- Routines and plans. Routine editor as an inline set-table view with a per
  exercise menu (rep target range or single, added or assisted for bodyweight,
  note, exercise info, previous sessions, remove).
- Bodyweight exercises: inferred from equipment, per set added or assisted weight,
  a bodyweight value frozen per finished workout for stats.
- Supersets.
- Rest timer with alert and a Lock Screen presence.
- History grouped by month and week, with a compact and an expanded view.
- Charts: estimated one-rep max and volume.
- Backup and export (JSON and a database file).
- Custom exercises. Set types and per set notes. Next-time targets.

## Data handover

The maintainer provides the current Forge SQLite database and a JSON export. The
new project reads both, and a one-time transform writes them into the new drift
schema. Preserve every value; only the field names and shape change.

## Kickoff prompt for the new chat

Open a new Claude Code chat with its working directory set to the new Flutter
project folder (a fresh directory, not this repo), then paste:

> Rewrite the Forge iOS strength-training app as a Flutter app, iOS first. The
> current SwiftUI version is at `/run/host/home/rodrigo/Downloads/Forge`. Use it as
> the reference for features and UI, read its `.claude/CLAUDE.md` for the product
> principles (local first, no server, no accounts, native feeling, data safe, plus
> the human-written-language rules), and read its `FLUTTER_PLAN.md` for the full
> plan and decisions. This is a clean-room rewrite (no Iron or Swift code copied),
> GPLv3, iOS only for now, with a shared Dart core for a later Android build.
> Persistence is drift/SQLite with a fresh schema; state is riverpod. No migration
> for real users. I will hand over my current Forge database for a one-time
> transform. First: run `flutter doctor`, scaffold so it runs as a Linux desktop
> or web build so you can run and screenshot the UI yourself, then build the Forge
> design system and the drift schema.
