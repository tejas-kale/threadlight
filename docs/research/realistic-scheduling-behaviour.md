# Realistic scheduling behaviour on macOS 27 and iOS 27

Research date: 9 September 2026
Decision ticket: [Establish realistic scheduling behaviour](https://github.com/tejas-kale/threadlight/issues/5)

## Decision summary

Threadlight should promise **one-tap foreground generation on either device**, not an automatically completed brief at an exact morning time.

- On macOS, offer opt-in automatic generation through a per-user `LaunchAgent` after the manual Mac milestone works. A calendar-triggered agent can run near the chosen time while the Mac is awake and the user is logged in; if the Mac is asleep, `launchd` runs the missed job after wake. It cannot generate while the Mac is powered off, and this design should not silently prevent sleep or change the user's power schedule.
- On iOS, treat automatic generation as an opportunistic enhancement. Submit a `BGAppRefreshTaskRequest` with a morning `earliestBeginDate`, but describe it as “attempt automatic generation”, never “generate at 07:00”. The system chooses whether and when to launch it.
- On both platforms, foregrounding Threadlight should immediately check whether today's Canonical Brief exists and offer or start a user-visible Brief Run if it does not. This is the dependable recovery path.
- Schedule a local morning notification as a fallback prompt. A notification can be delivered while the app is not running, but it does not execute the brief pipeline. After a successful background Brief Run, replace or cancel the fallback with a “Brief ready” notification where possible.
- A failed or expired Brief Run should remain non-canonical, record its source/model failure, and schedule another *opportunity*. Threadlight must not promise a retry deadline.

This preserves the product rule that Mac and iPhone do not intentionally create separate daily results: every scheduled or manual attempt must first check the shared Brief Day state and obey the separate cross-device claim/canonicalisation design.

## What the platforms actually guarantee

| Behaviour | macOS 27 | iOS 27 | Truthful product wording |
|---|---|---|---|
| User taps Generate while the app is active | The app can start work immediately, subject to source access, model availability and ordinary failures. | The app can start work immediately. If the person backgrounds it, a user-initiated continued-processing task may allow it to finish, but the system can still expire it. | “Generate now” |
| Automatic start at an exact wall-clock time | A registered `LaunchAgent` can use `StartCalendarInterval`; it runs on schedule when the relevant user session and Mac are available. A sleeping Mac catches up on wake rather than running at the missed time. | Not supported as a guarantee. `earliestBeginDate` is only a lower bound; Apple explicitly says launch at that date is not guaranteed. | Mac: “Generate automatically when this Mac is available.” iPhone: “Attempt automatic generation in the morning.” |
| Wake a sleeping device for Threadlight | A `LaunchAgent` calendar job does not promise to wake the Mac. Apple documents a separate, user-administered `pmset` power schedule, but Threadlight should not require or alter it by default. | Threadlight cannot demand a wake. Background execution is opportunistic, discretionary and influenced by usage, energy, network, thermal state and settings. | Never claim that Threadlight wakes either device at the brief time. |
| Finish an iPhone Brief Run after leaving the app | Not applicable to the Mac-first design. | `BGContinuedProcessingTask` is intended for work explicitly started by a person and can continue after the app backgrounds. It reports progress and supports cancellation, but requires expiration handling and does not convert a future scheduled job into guaranteed work. | “You can leave the app while this run finishes”; show failure if the system stops it. |
| Run Foundation Models in iPhone background time | The Mac helper still needs to check model availability before each run. | Apple engineers explicitly confirmed Foundation Models calls can run inside `BGAppRefreshTask` or `BGProcessingTask`; the model may rate-limit the call when the OS is busy, so the app must catch that error and retry later. | “Automatic generation depends on model availability.” |
| Notify at a chosen time | The system can deliver an authorised local calendar notification even when the app is not running. | Same. Notification permission and the user's current notification settings still govern presentation. | “Remind me to generate”; not “generate my brief”. |

## Recommended behaviour by milestone

### 1. Mac-first manual milestone

The first useful version should generate only from an explicit button press in the foreground. This isolates Gmail, EventKit and Foundation Models behaviour from scheduling and gives the learner a fast feedback loop.

Each run should:

1. check whether the Canonical Brief already exists for the current Brief Day;
2. expose progress per Source;
3. check `SystemLanguageModel` availability rather than assuming the model is ready;
4. commit a Canonical Brief only after the required pipeline completes under the agreed partial-failure policy; and
5. report failures in the UI without relying on a notification.

Apple notes that model availability depends on device and region, that model download can take time, and that apps must provide a fallback when the model is unavailable. This makes “the scheduler fired” distinct from “the brief completed”.

### 2. Opt-in Mac automatic generation

For this personal, initially non-App-Store Mac app, the strongest supported route is an embedded per-user `LaunchAgent` registered through `SMAppService` after explicit user approval. Apple documents `SMAppService` as the current API for registering helpers bundled with an app; registered LaunchAgents bootstrap for each subsequent login and run on behalf of the logged-in user.

Use `StartCalendarInterval` for the user's selected local morning time. Apple's `launchd` documentation says a calendar job missed during sleep starts on the next wake and coalesces multiple missed intervals into one. It also says a job does not run while the computer is powered off. Therefore:

- display the last automatic attempt and completion times;
- on launch and wake, perform the ordinary “does today's Canonical Brief exist?” check;
- do not use `StartInterval`, because a sleeping Mac can miss those interval firings;
- do not prevent system sleep merely to produce a brief; and
- do not promise operation before login, because a LaunchAgent belongs to the current user's session.

`NSBackgroundActivityScheduler` is a poorer fit for the morning trigger. Apple defines it for deferrable, low-priority work and gives the system flexibility based on energy, thermal and CPU conditions; its interval is suggested and its tolerance creates a scheduling window. It may still be useful for non-urgent maintenance, but not as Threadlight's user-facing daily clock.

The separate `pmset` facility can schedule a Mac wake, but configuring it is a machine-level user/admin choice. Keep it outside Threadlight's default setup. If Tejas later asks for stronger unattended Mac behaviour, document it as an advanced manual option and test lid-closed, battery, FileVault, logout and power-off cases on the actual M1 Air.

### 3. Independently generating iPhone companion

Use two complementary paths:

1. **Opportunistic automatic path:** submit one `BGAppRefreshTaskRequest` whose `earliestBeginDate` is the beginning of the desired morning window. Resubmit the next request from the task handler, because each request represents one launch. Keep the work atomic, cancel promptly through the expiration handler, and call `setTaskCompleted(success:)`.
2. **Dependable user path:** schedule an authorised local notification for the chosen time. Its text should depend on known state—for example, “Your brief may be ready” or “Open Threadlight to generate today's brief”—and opening Threadlight performs the canonical-state check and starts a foreground run if needed.

Apple gives `BGAppRefreshTask` only a short execution window (up to 30 seconds in its current guidance). A Gmail fetch plus EventKit reads plus local-model generation may exceed that budget. Measure the full pipeline on the target iPhone before selecting between:

- a compact `BGAppRefreshTask` that attempts the whole pipeline;
- a `BGProcessingTask` for the heavier work, accepting still more discretionary timing; or
- background source preparation followed by foreground model generation.

The first option is the motivating target, not an assumption. The app should expose which path produced the brief and the freshness of every Source Observation.

### 4. Retry and recovery policy

There is no platform promise that an unsuccessful background task will be retried at a particular time. Threadlight owns the retry state and asks the scheduler for another opportunity.

- On transient network, authentication, model-rate-limit or model-not-ready failure, persist a compact failure record and submit a later request with a bounded delay.
- On expiration, cancel promptly, leave no Canonical Brief, and resubmit. Apple requires an expiration handler and completion signalling; it may call the handler before the nominal allowance is exhausted.
- On permission denial or revoked credentials, do not spin in the background. Surface the required user action at next foreground launch and use a local notification only if the user has authorised notifications and the message is genuinely useful.
- Before every retry, re-check the Brief Day's shared canonical/claim state so that the other device's successful run wins.
- Cap attempts per Brief Day and keep the manual path available. Exact limits should be chosen after on-device measurements, not presented as platform guarantees.

## Product acceptance statements

Threadlight may claim:

- “Generate today's brief now” while the app is active.
- “Continue this user-started iPhone generation after you leave the app”, with visible progress/cancellation and honest expiration handling.
- “Attempt automatic generation in the morning on iPhone.”
- “Generate automatically when your signed-in Mac is available; a sleeping Mac catches up after wake.”
- “Notify me when a brief completes” and “Remind me to open Threadlight”.

Threadlight must not claim:

- an exact iPhone generation time;
- deterministic iPhone or Mac failover;
- that a local notification runs generation;
- that a calendar-triggered LaunchAgent wakes or powers on the Mac;
- that a submitted background task will run, finish, or retry by a deadline; or
- that Foundation Models will always be immediately available merely because the hardware is eligible.

## Validation still required during implementation

Apple's APIs establish the contract, but scheduling heuristics and workload duration require measurement. Before enabling automatic generation by default, run a shadow test on the actual M1 MacBook Air and iPhone Air covering:

- Mac awake, asleep then woken, logged out, powered off, lid closed and on battery;
- iPhone locked, Low Power Mode, Background App Refresh disabled, weak/no network and app seldom used;
- Foundation Models available, model-not-ready, rate-limited and task-expired cases;
- notification allowed, denied and later disabled in Settings; and
- simultaneous Mac/iPhone attempts, which must defer to the cross-device claim design.

Record observed completion windows as measurements, not guarantees. A realistic release gate is that failures are visible and recoverable, rather than that every background run lands at the same time.

## Primary sources

- Apple, [Choosing Background Strategies for Your App](https://developer.apple.com/documentation/backgroundtasks/choosing-background-strategies-for-your-app) — the system selects background launch timing; app refresh receives up to 30 seconds; background pushes are also discretionary.
- Apple, [`BGTaskRequest.earliestBeginDate`](https://developer.apple.com/documentation/backgroundtasks/bgtaskrequest/earliestbegindate) — a lower bound, explicitly not a guaranteed launch time.
- Apple, [Using background tasks to update your app](https://developer.apple.com/documentation/uikit/using-background-tasks-to-update-your-app) — task registration, one-request/one-launch scheduling, resubmission, expiration and completion handling.
- Apple, [Finish tasks in the background (WWDC25)](https://developer.apple.com/videos/play/wwdc2025/227/) — background work is opportunistic and may be postponed, throttled, suspended or terminated; continued processing is for explicit user-started work.
- Apple, [Coding Intelligence, Machine Learning & AI Group Lab (WWDC26), 11:22](https://developer.apple.com/videos/play/wwdc2026/8121/?time=682) — Foundation Models can run in iOS background tasks but may be rate-limited and should retry later.
- Apple, [Generating content and performing tasks with Foundation Models](https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models) — model availability must be checked and a fallback planned.
- Apple, [`SMAppService`](https://developer.apple.com/documentation/servicemanagement/smappservice) and [`register()`](https://developer.apple.com/documentation/servicemanagement/smappservice/register()) — current registration and user-approval model for bundled macOS LaunchAgents.
- Apple, [Scheduling Timed Jobs](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/ScheduledJobs.html) — `StartCalendarInterval`, catch-up after sleep and no execution while powered off. This guide is archived, so the behaviour must also be regression-tested on macOS 27.
- Apple, [`NSBackgroundActivityScheduler`](https://developer.apple.com/documentation/foundation/nsbackgroundactivityscheduler) — deferrable scheduling with system-selected timing and tolerance.
- Apple Support, [Schedule your Mac to turn on or off in Terminal](https://support.apple.com/en-gb/guide/mac-help/mchl40376151/mac) — the separate `pmset` power scheduling facility and its user/login constraints.
- Apple, [Scheduling a notification locally from your app](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app) and [requesting notification authorisation](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter/requestauthorization(options:completionhandler:)) — system-delivered local notifications, including while the app is not running, remain permission-controlled.
