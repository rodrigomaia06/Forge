# Forge backlog

The work items below, grouped by the app section they touch. Each item traces to a
roadmap phase (P0 through P11, from the original feature list) or to a code-audit finding,
or both. `[audit]` marks something already broken, stubbed, or dead in the current source,
with the file and line where it lives. `[Pn]` marks a planned feature from the roadmap.

`scripts/create-issues.sh` creates every item below as a GitHub issue with matching labels.

Status keys: some roadmap items are partly done from earlier work; those are noted.

## Foundation and cleanup (phase F)

- **[F][audit] Rename the internal module identity from Iron to Forge.** Bundle IDs and the
  display name are already Forge; the target/scheme/folder/module names, `project.yml`, CI,
  66 `import WorkoutDataKit` files, ~64 header comments, the hard-coded
  `group.com.kabouzeid.Iron` string, and the `iron_backup_file_images` / `iron_backups`
  asset folders still carry the fork name. Track as one epic with a checklist.
- **[F][audit] Remove the App Group launch migrations and their fatalError sites.** The free
  single-app build declares no App Group, but `Iron/AppDelegate.swift:18-22` runs four
  app-group migrations on every launch, and five `fatalError` sites
  (`UserDefaults+Migrate.swift:22`, `ExerciseStore+Migrate.swift:39`,
  `SettingsStore+Migrate.swift:18`, `WorkoutDataStorage+Migrate.swift:23,34`) crash without
  the entitlement. Highest-risk item. Also `FileManager+GroupContainerURL.swift:36`.
- **[F][audit] Remove Apple Watch companion remnants from the app target.**
  `NotificationManager.swift:109-115`, `UserDefaults+Misc.swift:14,26-31`, the `watchCompanion`
  setting (`SettingsStore.swift:92-98`, `UserDefaults+Settings.swift`), the `watch` log
  category, and the `WatchConnectionManager` comment in `Workout+Logic.swift:14`.
- **[F][audit] Remove Siri, widget, and StoreKit vestiges and the unbuilt target trees.**
  Widget reloads for a deleted widget (`AppDelegate.swift:25`,
  `WorkoutDataStorage+shared.swift:50`); the purchase/restore notification keys
  (`Notification.Name+RestoreFromBackup.swift:12-13,17`); the unbuilt `WatchIron/`,
  `WatchIron Extension/`, `IronIntents/`, `IronIntentsUI/`, `IronWidget/` directories.
- **[F][audit] Clean up leftover "remove in future" migrations.** Old notification
  identifiers (`NotificationManager.swift:132`, `SceneDelegate.swift:136`) and the
  pinned-charts legacy-key migrations (`UserDefaults+PinnedCharts.swift:29,44`).

## Design system (phase P0)

- **[P0] Add a theme layer with a user-selectable accent color and a contrast check.**
  A dark-first `Theme.swift` exists from earlier work; the accent is fixed. Add accent
  selection, light and dark parity, and an accessible-contrast guard.
- **[P0] Consolidate the shared UI primitives into one styled component set.** Replace the
  inline ad-hoc button and text-field styles with a small reusable set.
- **[P0][audit] Finish the NavigationStack and native-motion migration.** The four top-level
  tab pages were moved to `NavigationStack`; detail and sheet screens still use the deprecated
  `NavigationView` (for example `WorkoutDetailView`, `ExerciseDetailView`, the exercise sheets).
- **[P0] Accessibility pass on the restyled screens.** Light and dark, Dynamic Type,
  increased contrast, and VoiceOver on the core flows, with no clipped data at large sizes.
- **[P0][lower] Custom themes and a theme editor with contrast checks.** Falls out of the
  token layer above.

## Home

- **[P9] Make the dashboard cards reorderable and add-or-remove.** Generalize the existing
  pinned-charts model to cover the activity cards plus new next-workout, recent, and progress
  cards, with the layout persisted locally and a sensible default.
- **[P9][audit] Decide the fate of the orphaned original feed.** The pinned exercise charts,
  seven-day summary, and workouts-per-week chart still ship but are unreachable from the
  rewritten `FeedView`. Either wire them into the reorderable dashboard above or delete them
  (`ActivitySummaryLast7DaysView`, `ActivityCalendarView`, `ActivityWorkoutsPerWeekView`,
  `ExerciseChartViewCell`, `PinnedChartsStore`, `PinnedChart`, `UserDefaults+PinnedCharts`).
- **[audit] Home totals count uncompleted sets.** The stat tiles and volume sum every set,
  including empty placeholders, so they can overcount versus History's completed-only logic
  (`FeedView.swift:94-96,392`).
- **[audit] Make the recent-workout cards tappable.** The Home cards are display-only dead
  ends; add navigation into the workout and a way into full History (`FeedView.swift:328-336`).

## History

- **[audit] History crashes when the last workout is deleted.** The `.placeholder` FIXME is
  still live (`HistoryView.swift:93-94`).
- **[audit] Enable set reordering in the workout exercise detail.** The `.onMove` handler is
  commented out (`WorkoutExerciseDetailView.swift:191-206`).
- **[audit] Remove the always-on edit-mode leftovers in workout detail.** The `editMode`
  guards are commented out, so the editors always show (`WorkoutDetailView.swift:20,97-98,122`).
- **[audit] Add clear buttons to the title and comment fields.** In both history detail and
  the active workout (`WorkoutDetailView.swift:100`, `CurrentWorkoutView.swift:254`).
- **[audit] Re-enable workout sharing on iPad.** Currently gated out
  (`HistoryView.swift:58-65`).
- **[audit] Replace the force-cast of workout sets in exercise history.**
  `ExerciseHistoryView.swift:24` uses `as!`.
- **[audit] Verify the detail banner's accent contrast in dark mode.**
  `WorkoutDetailView.swift:94`.
- **[P7] Show last and best performance per exercise in history.** Builds toward the
  progression context in P7.

## Workout

- **[P1] Rebuild the rest timer as a Live Activity.** Lock Screen and Dynamic Island, using a
  widget-extension target and the persisted end-date. Requires moving the timer state out of
  `UserDefaults.standard`. Deferred by design in `project.yml:9-10`.
- **[P1] Restore the exact active-workout state after the app is killed.** The workout row is
  restored, but the selected tab, the exercise being edited, and scroll position are not.
- **[P1] Show inline "last time" performance beside the current set.** Values are pre-filled
  today but not shown inline as a reference.
- **[P1] Add next-session targets.** Add `targetWeight` and optional `targetRpe` to
  `WorkoutSet` (model v5); reps targets already exist.
- **[P1] Replace the repeating unfinished-workout notification with one configurable
  reminder.**
- **[P6][audit] Add a warm-up set type.** It is commented out today
  (`WorkoutSetTag.swift:12`, `WorkoutSetTag+SwiftUI.swift:16-17`, `WorkoutRoutineSet.swift:17`).
- **[P6] Add bodyweight sets with optional added or assisted weight.** Define how bodyweight
  interacts with volume and one-rep-max stats.
- **[audit] Add a plate calculator.** None exists.
- **[audit] Make the weight increment configurable per equipment.** Forced to 1 for
  non-barbell (`WorkoutSetEditor.swift:132-134`).
- **[audit] Give routine exercises default sets when added.**
  `WorkoutRoutineView.swift:69` adds an exercise with zero sets.
- **[P5] Add routine scheduling and planned targets.** Weekday assignment and per-set
  weight, effort, and rest for routines (model v6).
- **[P5] Let users set rep ranges on routine sets.** The set model carries min and max
  target repetitions, but the routine set editor does not expose a range, only a single
  value. Add min-to-max entry (for example 8 to 12) in `WorkoutRoutineSetEditor`.
- **[P5] Prompt to update the underlying routine after in-workout changes.**
- **[P4] Support placeholder exercises in routines.** Resolve the concrete exercise at start
  time (model v7); history already stores the concrete exercise.
- **[audit] Handle Core Data errors in the core workout actions instead of crashing.**
  `Workout+Logic.swift` uses `assertionFailure`/`fatalError` for start, cancel, finish,
  delete, and copy (`:19,34,47,66,77,121,132,143,154`).
- **[audit] Add a cancel confirmation on iPad for an active workout.**
  `CurrentWorkoutView.swift:235`.
- **[audit] Remove the App Store review prompt from the active workout.**
  `CurrentWorkoutView.swift:10,190`.
- **[audit] Replace the Color.fakeClear tap-gesture hacks.**
  `WorkoutRoutineExerciseView.swift:65`, `WorkoutExerciseDetailView.swift:159`.
- **[audit] Fix the rest-timer keep-running settings coupling.** Currently poked manually
  (`RestTimerStore.swift:72`, `GeneralSettingsView.swift:50`).
- **[audit] Let users set the default reps and weight for new sets.**
  `WorkoutExerciseDetailView.swift:98` hard-codes 5 reps.
- **[audit] Add a next-exercise or finish affordance in the exercise detail.**
  `WorkoutExerciseDetailView.swift:308`.

## Exercises

- **[P3] Edit any exercise via an override store keyed by UUID.** Built-ins are immutable
  bundled JSON; layer edits over them non-destructively rather than importing them.
- **[P3] Add custom categories and editable muscle groups.** Replace the hard-coded muscle
  dictionaries in `Exercise.swift`.
- **[P3] Expose the full custom-exercise fields.** The model already has alias, steps, and
  tips; the create API drops them.
- **[P3] Add a favorites and recents store.** Recents are partly derivable from history.
- **[P3] Archive custom exercises without deleting history.** Extend the hidden-UUID
  mechanism, which currently asserts against hiding customs.
- **[P3][audit] Add search to the per-group and hidden/custom lists, plus bulk operations.**
  Search exists only on the All list (`ExerciseMuscleGroupsView.swift:101`); `ExercisesView`
  has none. Add reorder and multi-select replace.
- **[P7][audit] Track personal records and show them per exercise.** One-rep-max chart data
  exists, but there is no explicit best-set or PR surface.
- **[audit] Require at least one muscle group for a custom exercise.**
  `CreateCustomExerciseSheet.swift:21`, `EditCustomExerciseSheet.swift:29`.
- **[audit] Add a delete confirmation on iPad for custom exercises.**
  `CustomExercisesView.swift:54`.
- **[audit] Remove the force-unwrap of the exercise description.**
  `ExerciseDetailView.swift:115`.
- **[audit] Let users choose the exercise chart timeframe and fix the stale header.** Fixed
  at three months with a "Sunrise Fit" header (`ExerciseChartView.swift:3,23`).

## Settings

- **[F][audit] Replace the remaining Iron branding and upstream links.** The rate label,
  About title and author, GitHub, Twitter, website, privacy-policy URL, App Store rating ID,
  and feedback email all point at upstream Iron (`SettingsView.swift:39,43,57,70`,
  `AboutView.swift:21,24,33,46,59,74`).
- **[audit] Replace the rootViewController mail-presentation hack.**
  `SettingsView.swift:59`.
- **[audit] Add a first-run onboarding flow.** None exists.
- **[P11] Add a readable CSV export.** Alongside the existing JSON and text exports.
- **[P11] Harden import: validate before replacing, snapshot a safety backup, and preview.**
  Current restore validates only by decode success; add version-compat and duplicate-UUID
  checks, a pre-import safety copy, and a counts-and-changes preview before the destructive
  replace.
- **[P11][audit] Replace fatal write paths with recoverable errors.** `saveOrCrash` and
  `finishOrCrash` on critical paths, plus the load-time `fatalError`s in
  `WorkoutDataStorage.swift:18,19,56`.
- **[P7] Add user-defined workout metadata fields.** Location, state, and similar, defined in
  Settings rather than hard-coded.
- **[P7] Add exclude-from-statistics on a workout.** For training logged elsewhere (model v9).
