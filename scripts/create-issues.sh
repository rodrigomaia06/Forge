#!/usr/bin/env bash
#
# Creates the Forge backlog as GitHub issues with per-section and per-phase labels.
# Source of truth for the human-readable list is docs/ISSUES.md.
#
# Requirements: the GitHub CLI (`gh`) authenticated against this repo.
#   gh auth login          # one time
#   ./scripts/create-issues.sh
#
# Labels are updated with --force, and issues are de-duplicated by title against the issues
# already in the repo, so the script is safe to re-run (for example after a rate-limit stop):
# it skips any issue whose exact title already exists. To preview without creating anything,
# run: DRY_RUN=1 ./scripts/create-issues.sh
#
set -euo pipefail

DRY_RUN="${DRY_RUN:-0}"
EXISTING_TITLES=""

if [[ "$DRY_RUN" != "1" ]]; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "error: gh (GitHub CLI) is not installed. See https://cli.github.com" >&2
    exit 1
  fi
  if ! gh auth status >/dev/null 2>&1; then
    echo "error: gh is not authenticated. Run: gh auth login" >&2
    exit 1
  fi
  # Snapshot existing titles (open and closed) once, for de-duplication on re-run.
  EXISTING_TITLES="$(gh issue list --state all --limit 500 --json title --jq '.[].title')"
fi

label() { # name color description
  if [[ "$DRY_RUN" == "1" ]]; then echo "label: $1"; return; fi
  gh label create "$1" --color "$2" --description "$3" --force >/dev/null
}

issue() { # title labels body
  if [[ "$DRY_RUN" == "1" ]]; then echo "issue: [$2] $1"; return; fi
  if grep -Fxq "$1" <<<"$EXISTING_TITLES"; then echo "skip (exists): $1"; return; fi
  gh issue create --title "$1" --label "$2" --body "$3" >/dev/null
  echo "created: $1"
}

# --- labels -----------------------------------------------------------------
label foundation 5319e7 "Rebrand, dead-code removal, project surgery"
label design     c5def5 "Design system and native motion (P0)"
label home       0e8a16 "Home dashboard"
label history    1d76db "Workout history"
label workout    d93f0b "Active workout and routines"
label exercises  8250df "Exercise database"
label settings   fbca04 "Settings, backup, about"
label bug        d73a4a "Broken or crashing today"
label enhancement a2eeef "New capability"
label cleanup    cfd3d7 "Remove or simplify existing code"
for p in F P0 P1 P3 P4 P5 P6 P7 P9 P11; do
  label "phase-$p" ededed "Roadmap phase $p"
done

# --- Foundation (phase F) ---------------------------------------------------
issue "Rename the internal module identity from Iron to Forge" "foundation,cleanup,phase-F" \
"Bundle IDs and the display name are already Forge; the fork name remains in the target,
scheme, folder, and module names.

Checklist:
- [ ] project.yml name, target keys, scheme (Iron, IronTests)
- [ ] Rename Iron/ and IronTests/ folders; Iron.xcodeproj
- [ ] PRODUCT_MODULE_NAME in Iron/Info.plist (SceneDelegate reference)
- [ ] Decide on WorkoutDataKit rename and update 66 import sites if renamed
- [ ] .github/workflows/ci.yml project and scheme references (lines 45-46, 95-96)
- [ ] Hard-coded group.com.kabouzeid.Iron string (FileManager+GroupContainerURL.swift:12, WorkoutExerciseMigrationPolicyV1.swift:16)
- [ ] Asset folders iron_backup_file_images/, IronTests/iron_backups/
- [ ] File header comments (~64 files: Iron, Sunrise Fit, Rhino Fit)
- [ ] Keep GPL LICENSE, copyright headers, and attribution"

issue "Remove the App Group launch migrations and their fatalError sites" "foundation,bug,phase-F" \
"The free single-app build declares no App Group, but app-group migrations run on every
launch and crash without the entitlement. Highest-risk item.

Where: AppDelegate.swift:18-22; UserDefaults+Migrate.swift:22; ExerciseStore+Migrate.swift:39;
SettingsStore+Migrate.swift:18; WorkoutDataStorage+Migrate.swift:23,34;
FileManager+GroupContainerURL.swift:36. Confirm the store lives in the app container and
remove the group-container code paths."

issue "Remove Apple Watch companion remnants from the app target" "foundation,cleanup,phase-F" \
"Dead watch code still compiles into the app.

Where: NotificationManager.swift:109-115; UserDefaults+Misc.swift:14,26-31; the watchCompanion
setting (SettingsStore.swift:92-98, UserDefaults+Settings.swift); the watch log category
(OSLog+Logs.swift:19); the WatchConnectionManager comment in Workout+Logic.swift:14."

issue "Remove Siri, widget, and StoreKit vestiges and the unbuilt target trees" "foundation,cleanup,phase-F" \
"Where: widget reloads for a deleted widget (AppDelegate.swift:25,
WorkoutDataStorage+shared.swift:50); purchase/restore notification keys
(Notification.Name+RestoreFromBackup.swift:12-13,17); the unbuilt WatchIron/,
'WatchIron Extension/', IronIntents/, IronIntentsUI/, IronWidget/ directories and their
entitlements."

issue "Clean up leftover remove-in-future migrations" "foundation,cleanup,phase-F" \
"Old notification identifiers (NotificationManager.swift:132, SceneDelegate.swift:136) and the
pinned-charts legacy-key migrations (UserDefaults+PinnedCharts.swift:29,44)."

# --- Design system (phase P0) ----------------------------------------------
issue "Add a theme layer with a selectable accent color and a contrast check" "design,enhancement,phase-P0" \
"A dark-first Theme.swift exists; the accent is fixed. Add accent selection, light and dark
parity, and an accessible-contrast guard."

issue "Consolidate the shared UI primitives into one styled component set" "design,cleanup,phase-P0" \
"Replace the inline ad-hoc button and text-field styles with a small reusable set."

issue "Finish the NavigationStack and native-motion migration" "design,cleanup,phase-P0" \
"The four top-level tab pages use NavigationStack. Detail and sheet screens still use the
deprecated NavigationView (WorkoutDetailView, ExerciseDetailView, the exercise sheets, and
others)."

issue "Accessibility pass on the restyled screens" "design,phase-P0" \
"Light and dark, Dynamic Type, increased contrast, and VoiceOver on the core flows, with no
clipped data at large text sizes."

issue "Custom themes and a theme editor with contrast checks" "design,enhancement,phase-P0" \
"Lower priority. Falls out of the token layer once the accent-color work lands."

# --- Home -------------------------------------------------------------------
issue "Make the dashboard cards reorderable and add-or-remove" "home,enhancement,phase-P9" \
"Generalize the pinned-charts model to cover the activity cards plus new next-workout,
recent, and progress cards, with the layout persisted locally and a sensible default."

issue "Decide the fate of the orphaned original feed" "home,cleanup,phase-P9" \
"The pinned exercise charts, seven-day summary, and workouts-per-week chart still ship but are
unreachable from the rewritten FeedView. Either wire them into the reorderable dashboard or
delete them (ActivitySummaryLast7DaysView, ActivityCalendarView, ActivityWorkoutsPerWeekView,
ExerciseChartViewCell, PinnedChartsStore, PinnedChart, UserDefaults+PinnedCharts)."

issue "Home totals count uncompleted sets" "home,bug" \
"The stat tiles and volume sum every set including empty placeholders, so they can overcount
versus History's completed-only logic (FeedView.swift:94-96,392)."

issue "Make the recent-workout cards tappable" "home,enhancement" \
"The Home cards are display-only dead ends. Add navigation into the workout and a way into
full History (FeedView.swift:328-336)."

# --- History ----------------------------------------------------------------
issue "History crashes when the last workout is deleted" "history,bug" \
"The .placeholder FIXME is still live (HistoryView.swift:93-94)."

issue "Enable set reordering in the workout exercise detail" "history,enhancement" \
"The .onMove handler is commented out (WorkoutExerciseDetailView.swift:191-206)."

issue "Remove the always-on edit-mode leftovers in workout detail" "history,cleanup" \
"The editMode guards are commented out, so the editors always show
(WorkoutDetailView.swift:20,97-98,122)."

issue "Add clear buttons to the title and comment fields" "history,workout,enhancement" \
"In both history detail and the active workout (WorkoutDetailView.swift:100,
CurrentWorkoutView.swift:254)."

issue "Re-enable workout sharing on iPad" "history,enhancement" \
"Currently gated out (HistoryView.swift:58-65)."

issue "Replace the force-cast of workout sets in exercise history" "history,bug" \
"ExerciseHistoryView.swift:24 uses as!."

issue "Verify the detail banner accent contrast in dark mode" "history" \
"WorkoutDetailView.swift:94."

issue "Show last and best performance per exercise in history" "history,enhancement,phase-P7" \
"Builds toward the progression context in P7."

# --- Workout ----------------------------------------------------------------
issue "Rebuild the rest timer as a Live Activity" "workout,enhancement,phase-P1" \
"Lock Screen and Dynamic Island, using a widget-extension target and the persisted end-date.
Requires moving the timer state out of UserDefaults.standard. Deferred by design
(project.yml:9-10)."

issue "Restore the exact active-workout state after the app is killed" "workout,enhancement,phase-P1" \
"The workout row is restored, but the selected tab, the exercise being edited, and scroll
position are not."

issue "Show inline last-time performance beside the current set" "workout,enhancement,phase-P1" \
"Values are pre-filled today but not shown inline as a reference."

issue "Add next-session targets" "workout,enhancement,phase-P1" \
"Add targetWeight and optional targetRpe to WorkoutSet (model v5). Reps targets already exist."

issue "Replace the repeating unfinished-workout notification with one configurable reminder" "workout,enhancement,phase-P1" \
"Refactor the repeating 15-minute notification into a single, user-configurable reminder."

issue "Add a warm-up set type" "workout,enhancement,phase-P6" \
"Commented out today (WorkoutSetTag.swift:12, WorkoutSetTag+SwiftUI.swift:16-17,
WorkoutRoutineSet.swift:17)."

issue "Add bodyweight sets with optional added or assisted weight" "workout,enhancement,phase-P6" \
"Define how bodyweight interacts with volume and one-rep-max stats."

issue "Add a plate calculator" "workout,enhancement" \
"None exists."

issue "Make the weight increment configurable per equipment" "workout,enhancement" \
"Forced to 1 for non-barbell (WorkoutSetEditor.swift:132-134)."

issue "Give routine exercises default sets when added" "workout,enhancement" \
"WorkoutRoutineView.swift:69 adds an exercise with zero sets."

issue "Add routine scheduling and planned targets" "workout,enhancement,phase-P5" \
"Weekday assignment and per-set weight, effort, and rest for routines (model v6)."

issue "Let users set rep ranges on routine sets" "workout,enhancement,phase-P5" \
"The set model carries min and max target repetitions, but the routine set editor exposes only
a single value. Add min-to-max entry (for example 8 to 12) in WorkoutRoutineSetEditor."

issue "Prompt to update the underlying routine after in-workout changes" "workout,enhancement,phase-P5" \
"Offer to save temporary in-workout changes back to the routine."

issue "Support placeholder exercises in routines" "workout,enhancement,phase-P4" \
"Resolve the concrete exercise at start time (model v7). History already stores the concrete
exercise."

issue "Handle Core Data errors in the core workout actions instead of crashing" "workout,bug" \
"Workout+Logic.swift uses assertionFailure/fatalError for start, cancel, finish, delete, and
copy (:19,34,47,66,77,121,132,143,154)."

issue "Add a cancel confirmation on iPad for an active workout" "workout,bug" \
"CurrentWorkoutView.swift:235 cancels without confirmation on iPad."

issue "Remove the App Store review prompt from the active workout" "workout,cleanup" \
"CurrentWorkoutView.swift:10,190."

issue "Replace the Color.fakeClear tap-gesture hacks" "workout,cleanup" \
"WorkoutRoutineExerciseView.swift:65, WorkoutExerciseDetailView.swift:159."

issue "Fix the rest-timer keep-running settings coupling" "workout,cleanup" \
"Currently poked manually (RestTimerStore.swift:72, GeneralSettingsView.swift:50)."

issue "Let users set the default reps and weight for new sets" "workout,enhancement" \
"WorkoutExerciseDetailView.swift:98 hard-codes 5 reps."

issue "Add a next-exercise or finish affordance in the exercise detail" "workout,enhancement" \
"WorkoutExerciseDetailView.swift:308."

# --- Exercises --------------------------------------------------------------
issue "Edit any exercise via an override store keyed by UUID" "exercises,enhancement,phase-P3" \
"Built-ins are immutable bundled JSON. Layer edits over them non-destructively rather than
importing them."

issue "Add custom categories and editable muscle groups" "exercises,enhancement,phase-P3" \
"Replace the hard-coded muscle dictionaries in Exercise.swift."

issue "Expose the full custom-exercise fields" "exercises,enhancement,phase-P3" \
"The model already has alias, steps, and tips; the create API drops them."

issue "Add a favorites and recents store" "exercises,enhancement,phase-P3" \
"Recents are partly derivable from history."

issue "Archive custom exercises without deleting history" "exercises,enhancement,phase-P3" \
"Extend the hidden-UUID mechanism, which currently asserts against hiding customs."

issue "Add search to the per-group and hidden or custom lists, plus bulk operations" "exercises,enhancement,phase-P3" \
"Search exists only on the All list (ExerciseMuscleGroupsView.swift:101); ExercisesView has
none. Add reorder and multi-select replace."

issue "Track personal records and show them per exercise" "exercises,enhancement,phase-P7" \
"One-rep-max chart data exists, but there is no explicit best-set or PR surface."

issue "Require at least one muscle group for a custom exercise" "exercises,bug" \
"CreateCustomExerciseSheet.swift:21, EditCustomExerciseSheet.swift:29."

issue "Add a delete confirmation on iPad for custom exercises" "exercises,bug" \
"CustomExercisesView.swift:54."

issue "Remove the force-unwrap of the exercise description" "exercises,bug" \
"ExerciseDetailView.swift:115."

issue "Let users choose the exercise chart timeframe and fix the stale header" "exercises,enhancement" \
"Fixed at three months with a Sunrise Fit header (ExerciseChartView.swift:3,23)."

# --- Settings ---------------------------------------------------------------
issue "Replace the remaining Iron branding and upstream links" "settings,foundation,phase-F" \
"The rate label, About title and author, GitHub, Twitter, website, privacy-policy URL, App
Store rating ID, and feedback email all point at upstream Iron (SettingsView.swift:39,43,57,70,
AboutView.swift:21,24,33,46,59,74)."

issue "Replace the rootViewController mail-presentation hack" "settings,cleanup" \
"SettingsView.swift:59."

issue "Add a first-run onboarding flow" "settings,enhancement" \
"None exists."

issue "Add a readable CSV export" "settings,enhancement,phase-P11" \
"Alongside the existing JSON and text exports."

issue "Harden import: validate before replacing, snapshot a safety backup, and preview" "settings,enhancement,phase-P11" \
"Current restore validates only by decode success. Add version-compat and duplicate-UUID
checks, a pre-import safety copy, and a counts-and-changes preview before the destructive
replace."

issue "Replace fatal write paths with recoverable errors" "settings,bug,phase-P11" \
"saveOrCrash and finishOrCrash on critical paths, plus the load-time fatalErrors in
WorkoutDataStorage.swift:18,19,56."

issue "Add user-defined workout metadata fields" "settings,enhancement,phase-P7" \
"Location, state, and similar, defined in Settings rather than hard-coded."

issue "Add exclude-from-statistics on a workout" "settings,enhancement,phase-P7" \
"For training logged elsewhere (model v9)."

echo "done."
