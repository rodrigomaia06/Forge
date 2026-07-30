<p align="center">
  <img width="180" height="180" src="assets/forge_icon_rounded.png" alt="Forge app icon">
</p>

# Forge

A focused, private strength-training tracker for iPhone, built in SwiftUI. Forge is
meant to feel like a well-made tool: quick to operate between sets, calm to look at,
and careful with your data.

## Screenshots

<table>
  <tr>
    <td align="center"><img src="assets/screenshots/dashboard.png" width="200" alt="Dashboard"><br>Dashboard</td>
    <td align="center"><img src="assets/screenshots/workout.png" width="200" alt="Live workout"><br>Live workout</td>
    <td align="center"><img src="assets/screenshots/warmup.png" width="200" alt="Warm-up calculator"><br>Warm-up calculator</td>
  </tr>
  <tr>
    <td align="center"><img src="assets/screenshots/routines.png" width="200" alt="Routines"><br>Routines</td>
    <td align="center"><img src="assets/screenshots/history.png" width="200" alt="History"><br>History</td>
    <td align="center"><img src="assets/screenshots/about.png" width="200" alt="About"><br>About</td>
  </tr>
</table>

## What Forge is for

Forge tracks weightlifting workouts and nothing else. It is built around a few priorities:

- Fast to operate during a workout, including one-handed and while tired.
- Private by default. Workout data stays on the device.
- Reliable when interrupted by a call, the screen locking, or the app being closed.
- Native to iOS, using standard controls and behaviour.

There are no accounts, no ads, and no tracking. It is not a social network, a coach,
or a subscription.

## Features

- Log a workout as a scroll of exercise cards, each with its set table inline
  (previous result, weight, reps), so logging never leaves the screen.
- Rest timer with a configurable alert sound and haptic, and a Lock Screen notification.
- Routines and plans to start a workout from a template, with drag-to-reorder exercises.
- History with each exercise's previous sessions, a date-range filter, and workout detail.
- Next-session targets that pre-fill the weight the next time you do an exercise.
- Set types (drop set, failure), plus per-set and per-exercise notes.
- Optional personal-record markers and RPE, both off by default.
- Light, dark, or system appearance.
- Custom exercises, backup, and export (JSON and a full database file).
- Dynamic Type, VoiceOver labels, and Reduce Motion support.

## Privacy

Forge stores workouts locally. It requires no account, includes no analytics or
advertising SDKs, and sends nothing off the device unless you deliberately export it.

## Installing

Forge is not on the App Store. You sideload the `.ipa` and sign it with your own free
Apple ID. This costs nothing, but a free Apple ID signature lasts seven days, so the tool
re-signs the app for you. You need an iPhone, a free Apple ID, and a computer. Get the
`.ipa` from the Releases page or a CI build artifact.

First, on the iPhone, turn on Developer Mode: Settings, Privacy & Security, Developer Mode.
iOS 16 and later require it for sideloaded apps.

### Install with iLoader

[iLoader](https://iloader.app) runs the same on Windows, macOS, and Linux:

1. Install iLoader and connect the iPhone. On Linux, install `usbmuxd` first if it is not
   already present.
2. Open iLoader and sign in with your Apple ID.
3. Import the Forge `.ipa` and install it to the phone. iLoader signs it with your Apple ID.

### Notes

- A free Apple ID allows three sideloaded apps at once and re-signs every seven days. If a
  refresh is missed the app stops opening until it is signed again. Your data is kept.
- The paid Apple Developer Program (99 USD per year) is only needed for TestFlight or the
  App Store, not for sideloading.

## Use of AI

Forge is developed with heavy use of an AI coding assistant (Claude Code). The assistant
writes and edits the code under human direction. Every change is built on CI
before it is merged, and the maintainer reviews behaviour and design. Treat the codebase
as AI-assisted work that is human-reviewed, not unchecked generation.

## Building

Building needs a Mac with Xcode. Without one, fork the repository and let its CI build the
app for you on a macOS runner. Both are covered in [docs/BUILDING.md](docs/BUILDING.md).

## License and attribution

Forge is derived from the open-source [Iron](https://github.com/kabouzeid/Iron) workout
tracker by Karim Abou Zeid, and is released under the same GNU General Public License v3.0.
See [LICENSE](LICENSE). Upstream copyright notices are preserved.
