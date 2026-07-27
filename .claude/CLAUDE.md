# CLAUDE.md

## Project identity

**Working name:** Forge

Forge is a focused, private, dependable strength-training app for iPhone. It should feel like a well-made tool rather than a service, social network, game, or storefront.

The project may be derived from the open-source Iron codebase. Preserve applicable license notices, attribution, and GPL obligations. Do not remove copyright headers or conceal upstream origins.

## North star

Every change should make the app:

- faster to operate during a workout
- easier to understand without instructions
- more reliable when interrupted
- safer for the user's data
- more consistent with native iOS behavior
- calmer and less distracting

When priorities conflict, prefer reliability, data integrity, privacy, and usability over novelty.

## Product character

Forge should feel:

- quiet
- direct
- durable
- native
- predictable
- respectful
- fast

It should not feel:

- promotional
- gamified
- needy
- cluttered
- social-first
- AI-first
- subscription-driven
- designed to maximize engagement

Do not add artificial urgency, streak pressure, guilt, celebratory clutter, mascots, pop-ups, retention tricks, or dark patterns.

## User relationship

The user owns the app experience and all data created in it.

Do not:

- place essential functionality behind a paywall
- show advertising
- require an account for ordinary use
- track behavior for marketing
- nag for ratings, upgrades, referrals, or notifications
- manipulate the user into spending more time in the app
- collect data merely because it may be useful later

Any optional permission must have a clear, immediate user benefit. The app must remain useful when optional permissions are denied.

## Interaction principles

Design for use between sets, when the user may be tired, moving, distracted, or operating the phone with one hand.

Prefer:

- large, forgiving tap targets
- obvious primary actions
- minimal typing
- sensible defaults
- immediate feedback
- reversible actions
- stable screen layouts
- preserving the user's place
- one clear task per screen

Avoid:

- deep navigation
- hidden gestures as the only control
- modal chains
- unnecessary confirmation dialogs
- tiny controls
- ambiguous icons
- controls that move after being tapped
- resetting scroll position or context unexpectedly

Common actions should require as few steps as reasonably possible. Do not optimize for screenshot aesthetics at the expense of speed during real use.

## Native iOS behavior

Use current Apple platform conventions unless there is a strong usability reason not to.

Prefer native SwiftUI or UIKit behavior for:

- navigation
- sheets
- menus
- alerts
- text input
- accessibility
- system appearance
- state restoration
- background transitions
- notifications
- haptics

Do not imitate another platform. Do not create custom controls when a native control is sufficient.

Support light mode, dark mode, Dynamic Type, Reduce Motion, increased contrast, VoiceOver, and common iPhone screen sizes.

The app must behave correctly when:

- moved to the background
- interrupted by a phone call
- the device locks
- the process is suspended
- the app is terminated and reopened
- the system changes appearance
- connectivity disappears
- the user changes locale, time zone, or clock format

Use platform-supported background mechanisms. Never rely on an ordinary in-process timer continuing indefinitely while the app is suspended.

## Visual direction

The visual system should be restrained and functional.

Use:

- clear hierarchy
- generous spacing
- strong typography
- high contrast
- consistent alignment
- limited visual decoration
- system materials where appropriate
- color to communicate meaning, not to decorate every element

Avoid:

- excessive gradients
- glass effects that reduce legibility
- unnecessary animation
- crowded dashboards
- decorative charts
- novelty typography
- color as the only source of meaning

Numbers and current workout state should be easy to scan at a glance.

## Data ownership and durability

User-created workout data is the most valuable part of the app.

Treat data loss, silent corruption, duplication, incorrect ordering, and broken migrations as critical defects.

Follow these rules:

- Store data locally by default.
- Keep the data model understandable and versioned.
- Make migrations explicit, tested, and recoverable.
- Never delete user data as part of a schema change without an intentional migration.
- Prefer stable identifiers over array positions or display names.
- Make destructive actions reversible when practical.
- Preserve historical records exactly unless the user explicitly edits them.
- Do not silently rewrite past records to match current defaults.
- Separate templates or definitions from completed historical records.
- Use transactional writes where partial updates could corrupt state.
- Save important state promptly rather than only when a screen closes.
- Test upgrade paths from realistic older databases.

Any import or restore operation must validate data before replacing the active store. Create a recovery path before destructive replacement.

## Privacy

Privacy is a default architecture choice, not a settings page.

- Do not include advertising SDKs.
- Do not include cross-app tracking.
- Do not create device fingerprints.
- Do not send workout or health data to a server unless the user deliberately invokes a clearly explained network operation.
- Do not include analytics by default.
- Never log workout contents, health information, personal notes, identifiers, tokens, or database records.
- Keep diagnostics minimal and non-sensitive.
- Do not require cloud services for core operation.
- Make network use visible and explainable.

If analytics or crash reporting is ever considered, it must be optional, privacy-preserving, documented, and easy to disable. Prefer no third-party telemetry.

## Security

Apply least privilege everywhere.

- Request only the entitlements and permissions currently required.
- Remove unused capabilities.
- Keep secrets out of source control, build logs, fixtures, screenshots, and crash reports.
- Never embed private keys, signing credentials, API secrets, or reusable access tokens in the app.
- Store sensitive credentials in Keychain when credentials are genuinely required.
- Use iOS data-protection APIs for private local files.
- Validate all imported, decoded, or externally supplied data.
- Treat malformed files as untrusted input.
- Use safe URL handling and restrict accepted schemes.
- Do not execute downloaded code.
- Avoid dynamic evaluation and unsafe deserialization.
- Do not weaken transport security settings to make a request work.
- Do not disable certificate validation.
- Avoid force-unwrapping data that can be malformed or absent.
- Fail safely and preserve existing user data.

Before adding a dependency, assess its ownership, maintenance status, license, data collection, network behavior, binary size, and supply-chain risk.

## Architecture

Prefer simple, explicit architecture over fashionable abstraction.

The codebase should have clear boundaries between:

- presentation
- application state
- domain logic
- persistence
- platform integrations
- import and export
- background or lifecycle coordination

Rules:

- Keep business rules out of views.
- Keep persistence details out of UI components.
- Make state ownership obvious.
- Prefer value types for domain models where practical.
- Keep side effects explicit.
- Use dependency injection where it improves testing, not as ceremony.
- Avoid global mutable state.
- Avoid singletons unless wrapping a true process-wide system service.
- Prefer small, composable types with narrow responsibilities.
- Delete dead code instead of preserving speculative paths.
- Do not introduce a framework to solve one small problem.
- Do not rewrite a stable subsystem without a measurable benefit.

When working in inherited code, understand the existing data flow before refactoring it. Preserve behavior first, then simplify in small verified steps.

## Code quality

Write code for the next maintainer, not only for the compiler.

- Use clear names that reflect domain meaning.
- Prefer straightforward control flow.
- Keep functions focused.
- Avoid cleverness and premature generalization.
- Document why a non-obvious decision exists.
- Do not comment what the code already says.
- Resolve warnings rather than suppressing them.
- Avoid force casts and force unwraps in production paths.
- Handle cancellation correctly in asynchronous work.
- Keep UI updates on the appropriate actor.
- Make concurrency boundaries explicit.
- Ensure tasks do not outlive the state they mutate.
- Avoid retain cycles in closures and observers.
- Remove temporary debug code before completion.

Use formatting and linting consistently, but do not make broad formatting-only changes inside unrelated work.

## Error handling

Errors should be actionable, calm, and honest.

User-facing errors must:

- explain what failed in plain language
- avoid exposing implementation details
- preserve the user's current work
- offer a useful recovery action when one exists
- avoid blaming the user
- never claim success when a write may have failed

Do not swallow errors silently. Log only enough non-sensitive context to diagnose the problem.

When an operation cannot complete safely, leave the previous valid state untouched.

## Performance

The app should feel immediate on ordinary supported iPhones.

- Keep launch work minimal.
- Avoid blocking the main thread.
- Do not load the entire database when a smaller query is sufficient.
- Avoid unnecessary view recomputation.
- Use lazy containers for large collections.
- Cache only when correctness and invalidation are clear.
- Measure before optimizing.
- Prefer lower energy use over needless background activity.
- Avoid continuous polling.
- Ensure timers and observers are invalidated correctly.
- Test with realistically large workout histories.

A visual animation must not delay input or data persistence.

## Accessibility

Accessibility is part of correctness.

- Every interactive element must have a meaningful accessibility label.
- Do not rely only on color, shape, position, or haptics.
- Support Dynamic Type without clipping important data.
- Preserve usable tap targets at large text sizes.
- Keep reading order logical.
- Announce important state changes appropriately.
- Respect Reduce Motion.
- Use plain language.
- Do not encode essential meaning only in abbreviations.

Test core flows with VoiceOver and large accessibility text sizes.

## Localization and formatting

Do not build user-facing strings by concatenating fragments.

- Use localized string resources.
- Use locale-aware number, date, duration, and unit formatting.
- Respect 12-hour and 24-hour clock preferences.
- Avoid fixed-width assumptions for translated text.
- Keep layout resilient to longer strings.
- Store dates and durations in unambiguous machine representations.
- Do not store formatted display strings as source data.

## Dependencies

The default answer to a new dependency is no.

Add one only when it provides substantial value that would be costly or risky to implement correctly.

For every dependency:

- justify why it is needed
- prefer source-visible and actively maintained libraries
- verify license compatibility
- pin or constrain versions intentionally
- review release notes before upgrades
- avoid packages that add analytics, ads, tracking, or unnecessary networking
- remove unused dependencies
- keep the app buildable without private package registries

Prefer Apple frameworks and small internal implementations for simple needs.

## Testing expectations

Changes are incomplete until the relevant behavior is tested.

Prioritize tests for:

- domain calculations
- persistence
- database migrations
- interruption and restoration
- import validation
- destructive operations
- date and duration handling
- locale and time-zone behavior
- background-to-foreground transitions
- large histories
- failure recovery

Use:

- unit tests for domain and data logic
- integration tests for persistence and migrations
- UI tests for critical flows
- manual device testing for lifecycle, notifications, accessibility, and system surfaces

Tests must verify behavior, not implementation details.

Never delete or weaken a test merely to make a change pass unless the expected behavior itself has intentionally changed and the reason is documented.

## Build and repository hygiene

Keep the project reproducible.

- Do not commit signing certificates, provisioning profiles, Apple account data, secrets, or personal team identifiers.
- Keep bundle identifiers and signing configuration easy to override.
- Keep generated files out of version control unless required for reproducible builds.
- Maintain clear build instructions for local Xcode and CI macOS runners.
- Do not assume the contributor owns a Mac outside the macOS build environment.
- Keep CI scripts readable and minimal.
- Fail CI on compilation errors, test failures, and unsafe migration failures.
- Do not make releases from unreviewed local state.

Preserve upstream license files and document meaningful modifications to inherited code.

## Change discipline

Before editing:

1. Read the relevant code paths.
2. Identify the source of truth.
3. Check how the data is persisted.
4. Check lifecycle and interruption behavior.
5. Find existing tests.
6. Understand whether the change affects old user data.

While editing:

- Make the smallest coherent change.
- Keep unrelated refactors separate.
- Preserve compatibility unless there is a documented reason not to.
- Prefer reversible migrations.
- Add tests alongside behavior changes.
- Do not leave partially migrated code paths.

After editing:

- Build the affected targets.
- Run relevant tests.
- Check warnings.
- Test failure states.
- Check accessibility.
- Verify no sensitive data is logged.
- Summarize changed behavior and risks.
- Note anything that could not be verified.

## Decision rules for Claude Code

When asked to implement or modify something:

- Do not immediately write code before understanding the relevant models and persistence path.
- Inspect existing conventions and follow them unless they are unsafe.
- State assumptions when the codebase does not make intent clear.
- Prefer a small patch over a broad rewrite.
- Protect existing user data above all.
- Do not invent backend services, accounts, analytics, or monetization.
- Do not add unrelated functionality.
- Do not silently change established behavior.
- Do not remove compatibility code without proving it is no longer needed.
- Do not claim a build or test passed unless it was actually run.
- If an iOS capability cannot be verified outside Xcode or a physical device, say so explicitly.
- Flag licensing, signing, entitlement, privacy, migration, and App Store implications when relevant.
- Treat compiler warnings, concurrency warnings, and migration warnings as real problems.
- Prefer platform-supported solutions over hacks that may break after an iOS update.

## Definition of done

A change is done only when:

- it matches the product character
- the common path remains fast and obvious
- existing user data remains safe
- failure states are handled
- accessibility is preserved
- privacy is not weakened
- permissions and entitlements remain minimal
- relevant tests exist and pass
- the project builds for the affected targets
- no new warnings are introduced
- documentation is updated where needed
- the implementation is understandable without hidden context

The final result should feel like Forge has always worked that way.


## Human-written product language

All Forge language must sound deliberate, specific, and written for the situation. It must not sound like generic assistant output, marketing copy, or a reusable content template.

These rules apply to interface text, notifications, onboarding, permissions, errors, release notes, documentation, code comments, pull request descriptions, and generated summaries. They do not apply to user-authored content, required legal text, quoted material, or code syntax.

### Goal

The goal is a consistent editorial voice, not evasion of AI detectors.

Do not introduce typos, slang, fragments, or awkward phrasing to appear human. Text should feel human because it is concrete, restrained, context-aware, and carefully edited.

### Voice

Use a calm, practical, and direct voice.

Prefer:

* plain words
* short labels
* active verbs
* concrete explanations
* natural contractions when they fit
* terminology already used elsewhere in Forge

Avoid:

* marketing language
* corporate language
* motivational coaching
* exaggerated enthusiasm
* generic reassurance
* assistant or mascot personality
* language that treats ordinary actions as achievements

Forge is a tool. It does not cheerlead, flatter, guilt, tease, celebrate itself, or pretend to be the user's friend.

### Punctuation and symbols

Do not use emojis in project-owned text.

This includes headings, bullets, buttons, notifications, empty states, release notes, commits, pull requests, documentation, and sample data maintained by the project.

Use an SF Symbol or another native visual element when an interface needs an icon. Give visual icons proper accessibility labels. Do not use emoji as a substitute for interface design.

Do not use em dashes in project-owned prose. Rewrite with a period, comma, colon, semicolon, or parentheses.

Do not imitate an em dash with spaced hyphens.

Avoid ellipses unless they indicate an actual unfinished or ongoing operation.

Use exclamation marks only when the meaning genuinely requires urgency. Do not use repeated punctuation for emphasis.

### Capitalization and formatting

Use sentence case for headings, labels, menu items, documentation headings, and release notes unless a proper name or Apple platform convention requires otherwise.

Do not use title case merely to make text appear polished.

Do not bold every important phrase.

Do not create a heading for every paragraph.

Do not turn prose into a list unless the items are genuinely separate and easier to scan as a list.

Do not force every explanation into an introduction, numbered list, summary, and conclusion.

### Stock language

Avoid generic AI-like and promotional wording unless it is the precise technical term required by the context.

Common examples include:

* delve into
* dive into
* at its core
* in today's fast-paced world
* ever-evolving landscape
* navigate the landscape
* realm
* tapestry
* multifaceted
* pivotal
* underscore
* unlock
* empower
* elevate
* leverage, when "use" is accurate
* seamless
* robust, when a specific property can be named
* cutting-edge
* transformative
* game-changing
* holistic
* thoughtfully designed
* designed with you in mind
* take your workouts to the next level
* crush your goals
* fitness journey
* stay motivated
* smarter, not harder
* all-in-one
* powerful yet simple

Do not replace one stock phrase with another. State the actual fact.

Prefer:

"Your workouts stay on this iPhone."

Avoid:

"A seamless, privacy-first experience designed to empower your fitness journey."

### Canned structures

Avoid habitual use of patterns such as:

* It is not just X, it is Y.
* More than just X, Forge is Y.
* This is where X comes in.
* The result? X.
* Here is the thing.
* Let that sink in.
* Imagine a world where...
* Whether you are a beginner or an expert...
* From X to Y, Forge...
* At the end of the day...
* In conclusion...
* It is important to note that...
* That being said...
* Despite these challenges...
* With that in mind...

These phrases are not forbidden because they prove AI authorship. They are avoided because they often add scaffolding without adding information.

Make the claim directly.

### Structure and rhythm

Do not make every paragraph the same length.

Do not make every sentence follow the same grammatical pattern.

Do not begin several consecutive sentences or bullets with the same word unless parallel structure materially improves comprehension.

Do not default to groups of three. Use the number of items the content requires.

Avoid one-word fragments added only for drama.

Avoid repeated rhetorical questions.

Avoid question-and-answer constructions when a direct statement is clearer.

Do not add a closing paragraph that only repeats the preceding section.

Do not hedge automatically. Use uncertainty only when uncertainty is real.

Do not add throat-clearing introductions. Start with the information the user needs.

### Specificity

Every claim should provide useful information.

Replace broad praise with observable behavior.

Prefer:

* The timer continues on the Lock Screen.
* The import was rejected because two exercise IDs were duplicated.
* No workout data leaves the device.

Avoid:

* The experience is seamless.
* The system is robust.
* Forge makes tracking easier than ever.
* This important improvement enhances usability.

Do not invent user needs, statistics, testimonials, benefits, or emotional reactions.

Do not say users love, need, struggle with, or want something unless project research supports the statement.

Do not use unsupported superlatives such as best, fastest, most advanced, or ultimate.

### Interface copy

Button labels should name the action.

Prefer:

* Save workout
* Add set
* Replace exercise
* Try again
* Open Settings

Avoid:

* Let's go
* Make it happen
* Start my journey
* Unlock progress
* Continue the experience

A short Done or OK label is acceptable when it follows native iOS conventions and the action is unambiguous.

Empty states should explain the state and offer one useful next action when needed.

Prefer:

"No routines yet. Create a routine to plan a workout."

Avoid:

"Your fitness journey starts here. Create your first routine and unlock your potential."

Success messages should confirm the result without praise.

Prefer:

* Workout saved.
* Routine duplicated.
* Backup created.

Avoid:

* Amazing work!
* You crushed it!
* Great job!
* Success! Your workout has been saved!

Error messages should state what failed, preserve the user's work, and provide the next useful action.

Prefer:

"The backup could not be opened because its format is not supported. Your current data was not changed."

Avoid:

"Oops! Something went wrong. Please try again later."

Notifications should be factual, brief, and useful.

Prefer:

* Rest timer ended
* Workout still in progress
* Backup completed

Avoid jokes, guilt, praise, invented urgency, and decorative symbols.

### Permission copy

Explain a permission when it is needed.

State:

1. what access is requested
2. what action requires it
3. whether Forge remains usable without it

Do not use fear, pressure, repeated prompts, or vague benefit claims.

Avoid:

* Enable this for the best experience.
* Do not miss out.
* Unlock the full power of Forge.
* Allow access to continue your journey.

### Documentation and comments

Documentation should begin with the relevant information, not a generic overview.

Do not add sections named Key takeaways, Why this matters, The bigger picture, or In conclusion unless they serve a specific need.

Do not restate the same point in an opening, bullet list, and closing summary.

Code comments should explain a constraint, reason, invariant, workaround, or non-obvious decision. Do not narrate obvious code.

Prefer:

"Store the end date instead of remaining seconds because the process may be suspended."

Avoid:

"This code robustly handles the timer and ensures a seamless experience."

Pull request descriptions and change summaries should report:

* what changed
* why it changed
* what was tested
* known risks or limitations

Do not add congratulations, generic confidence statements, decorative language, or filler conclusions.

### Review generated text

Before accepting project-owned text produced with assistance, check for:

1. emojis or decorative Unicode
2. em dashes or spaced-hyphen substitutes
3. title-case headings
4. canned transitions
5. stock AI vocabulary
6. unnecessary adjectives and adverbs
7. repeated sentence structures
8. artificial groups of three
9. unnecessary headings or lists
10. generic claims without concrete detail
11. conclusions that repeat earlier text
12. praise, guilt, hype, or assistant personality
13. unsupported facts or invented user opinions
14. inconsistent terminology
15. wording that could be pasted unchanged into an unrelated app

Read important interface text aloud. If it sounds like marketing copy, a chatbot response, or a generic productivity app, rewrite it.

### Instructions for Claude Code

When Claude Code creates or edits text:

* inspect nearby project language first
* reuse established terminology
* preserve sentence case
* produce only the amount of copy the interface needs
* do not add emojis
* do not use em dashes
* do not create slogans
* do not add motivational messages
* do not invent feature benefits
* do not add generic introductions or conclusions
* do not reorganize text into headings and bullets without a usability reason
* do not use polished vagueness instead of a concrete explanation
* do not intentionally add errors or inconsistency to simulate human writing
* preserve existing meaning unless the task explicitly changes product behavior

Product language is acceptable when it communicates the needed fact or action immediately, matches Forge's quiet character, contains no engagement language, and could not be pasted unchanged into an unrelated fitness app.
