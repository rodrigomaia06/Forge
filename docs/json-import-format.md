# JSON import format

Forge can import a plain JSON file that adds plans, routines, and past workouts. Use it to move data
in from another app, restore a shared plan, or hand-author a routine.

Import it in the app under **Settings → Backup & Export → Share → Import from file**. Before anything
is written, Forge shows what the file contains and asks you to confirm. Everything is added with new
identifiers, so an import never changes or overwrites data you already have. Workouts in the file are
added to your **History**.

This is separate from **Import Database**, which replaces the whole database with a `.sqlite` backup.
Use JSON to merge things in; use the database import to restore a full backup.

## Shape

```json
{
  "formatVersion": 1,
  "plans": [
    {
      "title": "Pull",
      "routines": [
        {
          "title": "Pendulum",
          "comment": "optional",
          "attributes": { "Location": "Home gym" },
          "exercises": [
            {
              "exerciseUuid": "0FEC9D1B-2A0A-5A2E-9E2D-9B3F7C1A2B3C",
              "comment": "optional",
              "sets": [
                { "minReps": 8, "maxReps": 12, "tag": "dropSet", "comment": "optional" }
              ]
            }
          ]
        }
      ]
    }
  ],
  "routines": [
    { "title": "Standalone routine", "exercises": [] }
  ],
  "workouts": [
    {
      "title": "Chest",
      "comment": "optional",
      "start": "2026-07-06T17:35:26Z",
      "end": "2026-07-06T19:18:23Z",
      "attributes": { "Mood": "Good" },
      "exercises": [
        {
          "exerciseUuid": "0FEC9D1B-2A0A-5A2E-9E2D-9B3F7C1A2B3C",
          "sets": [
            { "weight": 40.0, "reps": 10, "isCompleted": true, "tag": "failure", "rpe": 9.0 }
          ]
        }
      ]
    }
  ]
}
```

## Fields

Top level. Every array is optional; include only what you need (a file can be just `plans`, just a
`routines` list, just `workouts`, or any mix).

- `formatVersion` (required): use `1`. A file from a newer version than the app is rejected.
- `plans`: workout plans, each with a `title` and a list of `routines`.
- `routines`: routines that belong to no plan (imported as standalone routines).
- `workouts`: finished sessions, added to History.

Routine (inside a plan's `routines`, or in the top-level `routines`):

- `title`, `comment`: optional text.
- `attributes`: optional string-to-string map (your own fields, like location or mood).
- `exercises`: ordered list of routine exercises.

Routine exercise:

- `exerciseUuid` (required): the UUID of a Forge exercise (see below).
- `comment`: optional.
- `sets`: ordered list. Each set may have `minReps`, `maxReps` (a single target uses the same value
  for both), an optional `tag`, and an optional `comment`.

Workout:

- `title`, `comment`: optional.
- `start`, `end`: ISO 8601 timestamps (for example `2026-07-06T17:35:26Z`). If only one is given the
  other is filled in; a workout with neither gets the import time.
- `attributes`: optional string-to-string map.
- `exercises`: ordered list of workout exercises.

Workout exercise:

- `exerciseUuid` (required).
- `sets`: ordered list. Each set may have `weight` (kilograms), `reps`, `isCompleted` (default the set
  is treated as logged), an optional `tag`, `rpe`, `comment`, and planned `minTargetReps` /
  `maxTargetReps` shown as the target hint.

## Tags

`tag` accepts one of: `warmUp`, `dropSet`, `failure`, `backOff`. Any other value is ignored.

## Exercise UUIDs

`exerciseUuid` must match a Forge exercise. The built-in catalog lives at
`WorkoutDataKit/everkinetic-data/exercises.json`, where each entry has a `title` and a `uuid`; use the
`uuid` of the exercise you want. A UUID the app doesn't know shows as "Unknown Exercise" rather than
creating a new exercise, so map to real catalog UUIDs.

Weights are stored in kilograms. Convert before writing the file if your source is in pounds.
