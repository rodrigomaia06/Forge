# Freeze and lag audit

A read of every source file in Forge, looking for what could leave the UI unresponsive with a
force-quit as the only recovery, and for what could make it lag short of that.

Nothing here has been run. There is no Mac in this environment, so none of it is measured, and the
ranking is from reading the code, not from a trace.

## What the symptom narrows it to

The rest timer stores an end date in `UserDefaults` (`RestTimerStore.restTimerStart` plus
`restTimerDuration`) and derives the remaining time from `Date()` on read. Time therefore advances
whether or not the app is alive, so a timer that has expired by the time Forge is reopened confirms
only that the store is intact. It does not say the app was running.

The deciding observation is the workout stopwatch: **during a freeze it stops on a value rather than
continuing to count.** The main thread is therefore blocked, not merely starved of touches. That
rules out the gesture-arbitration findings (3 and 4 below, kept for the record) and puts the weight
on anything that does synchronous work on the main thread.

## Fixed

### 1. ActivityKit was called synchronously from the set-completion path

Every call in `RestTimerLiveActivityController` crossed to the ActivityKit daemon and blocked until
it answered: `ActivityAuthorizationInfo()`, `Activity.request`, and enumerating
`Activity<RestTimerAttributes>.activities`. The caller chain was `completeSet` (a tap handler on the
main thread) to `RestTimerStore.restTimerStart`'s setter to `updateNotification()` to `sync`, running
inline just before the Core Data save.

So every tap on a set's checkmark made a synchronous daemon round trip on the main thread. Normally a
hitch. If the daemon is slow or wedged, a stall of unbounded length, with the stopwatch frozen and
the rest timer still advancing because it is a stored date. That is the closest match to the reported
symptom.

Now serialised onto a private queue. Nothing in that controller draws, and the widget counts down
from the dates on its own, so a late hand-off is not visible.

To confirm it was the cause: the freeze should stop happening. To confirm it was not, turn Live
Activities off in system settings on the old build and see whether the freeze persists.

### 2. Every exercise lookup rebuilt and copied the 217-entry catalog

`ExerciseStore.exercises` was a computed `builtInExercises + customExercises`, so each read allocated
and copied a 217-element array of structs (each with seven string arrays inside). `shownExercises`
additionally ran `isHidden` across all of it. There are around fifty call sites, and the costly ones
run per row and inside view bodies:

- `CurrentWorkoutView.body` reads it for `displayTitle`, which falls through to `muscleGroups(in:)`
  and one lookup per exercise in the workout. That body re-evaluates on every save, so on every
  completed set and every committed field.
- `FeedView.workoutCard` per card, `HistoryView` per row, `WorkoutExerciseDetailView` for both
  `exerciseTitle` and `exerciseIsBodyweight`.

`exercises`, `shownExercises` and `hiddenExercises` are now stored and rebuilt only when the custom
exercises or the per-exercise settings change, and there is a UUID index behind `find(with:)`.

### 3. The dashboard walked the whole history several times per render

`FeedView` holds an unbounded `@FetchRequest` of every finished workout and walked it repeatedly:
twice for the stat tiles, once for the month grid, twelve times for the mini month grids with the
year open, twelve more for their accessibility labels, and once for the list. `cal` was a computed
property that copied `Calendar.current` on each access, and it was read *inside* those closures, so
it was one calendar copy per workout per pass. With `fetchBatchSize = 20` each pass was also a SQL
round trip every twenty rows, so the whole thing grew linearly with the user's history.

Replaced with a single pass into an `ActivityIndex` (days and counts keyed by month, plus the two
tile counts), built once per render and threaded down along with one calendar.

### 4. The exercise info screen rasterised PDFs inside `body`

`ExerciseDetailView` called `exerciseImages(width:height:)` from `body`, inside a `GeometryReader`
inside a `List`. Per image that meant opening a `CGPDFDocument`, drawing the page through
`UIGraphicsImageRenderer`, and a second full off-screen pass to tint it, with no cache, repeated on
every body evaluation. A `GeometryReader` in a `List` re-evaluates on scroll and on any size change.

Removed outright along with the bundled illustrations (317 PDFs, 5.4 MB), the `pdf` key in
`exercises.json`, `Exercise.pdfPaths`, `AnimatedImageView`, and `UIImage.tinted(with:)`. The
`GeometryReader` went with it, since sizing the illustration was its only purpose.

## Still open

### 5. The set editor puts a drag gesture over the whole editor

[WorkoutSetEditor.swift:335](../Forge/UI/Workout/WorkoutSetEditor.swift#L335) attaches
`.gesture(DragGesture())` to the root of the editor. Everything inside it is interactive: two
`Dragger`s with their own `.gesture` plus a `.simultaneousGesture(TapGesture())`, the numeric
keypad's buttons, and the tag and done buttons. `.gesture` rather than `.simultaneousGesture` makes
the outer drag compete with all of them, over a view that also hosts a `UITextField`. That is the
same shape as the `scrollDismissesKeyboard(.interactively)` freeze fixed in 0aee19d.

Left alone for now because it would starve touches rather than block the main thread, and the
stopwatch says the main thread is what stops. Worth changing anyway: the handler only reads
`predictedEndTranslation` in `onEnded`, so `.simultaneousGesture` costs nothing.

Separately, `width < 200` in that handler is true for every leftward swipe and most small ones, so a
stray horizontal drag anywhere in the editor switches the keyboard to weight. That is a plain bug in
the same block.

### 6. Core Data changes are delivered in a run loop mode that excludes scrolling

[WorkoutDataStorage+shared.swift:26-31](../Forge/Extension/WorkoutDataStorage+shared.swift#L26-L31)
uses `.receive(on: RunLoop.main)`, which schedules in the default run loop mode only. While a scroll
is tracking, the run loop is in `UITrackingRunLoopMode`, so the whole `objectWillChange` fan-out is
held. The comment says this is deliberate, and it is a reasonable trade, but the UI genuinely does
not update during a scroll.

### 7. The old window-level tap recognizer is still in the source

[`KeyboardDismissInstaller`](../Forge/UI/SwiftUISupport.swift#L200-L253) is a full implementation
whose `shouldRecognizeSimultaneouslyWith` returns `true` for every gesture. Nothing calls `install()`
any more and `dismissesKeyboardOnBackgroundTap()` is a no-op, so it is dead rather than dangerous. It
should be deleted rather than left for someone to wire back up.

### 8. One fetched-results controller per exercise in the live workout

[WorkoutExerciseDetailView.swift:22](../Forge/UI/History/WorkoutExerciseDetailView.swift#L22)
declares a `@FetchRequest` for that exercise's history, and the live workout instantiates one view
per exercise. Each is a separate controller on the same context, so every `saveOrCrash()` (once per
completed set, once per committed field) re-evaluates all of them. There is no `fetchLimit`, even
though `displayedHistory` shows three by default and `previousPerformance` only reads `.first`.

Adding `fetchLimit` would cut most of it.

### 9. The one-second timers are rebuilt every time they fire

Three views do `.onReceive(Timer.publish(every:on:in:).autoconnect())` inside `body`:
[TimerBannerView:132](../Forge/UI/Workout/TimerBannerView.swift#L132),
[RestTimerView:86](../Forge/UI/Workout/RestTimerView.swift#L86), and
[Dragger's `Cursor`:265](../Shared/UI/SwiftUI/Controls/Dragger.swift#L265).

`Timer.publish` returns a new publisher on each call, so each body evaluation builds another one. The
handler then changes state, which re-evaluates the body, which builds another publisher, so the
subscription is torn down and a run loop timer invalidated and rescheduled on every tick. The
`Cursor` does this every 0.6 seconds for as long as a value field is focused.

Hoisting the publisher into a stored `let` fixes it.

### 10. `Refresher` is allocated on every view init

`@ObservedObject private var refresher = Refresher()` appears in four views. `@ObservedObject` does
not own its object, so a new `Refresher` is allocated and subscribed each time the view struct is
recreated. It works, but it is churn on the hot path and it makes finding 9 harder to reason about.

## If the freeze persists

The four fixed items were the main thread's synchronous work. If it still happens, the next things to
look at, in order:

1. Attach Instruments' Time Profiler and freeze it deliberately. With the stopwatch stopping, the
   blocked stack will be sitting right there on the main thread.
2. Findings 8 and 9, which are the remaining per-save and per-second main-thread work.
3. Finding 5, in case the gesture wedge and the stall are two separate problems.
