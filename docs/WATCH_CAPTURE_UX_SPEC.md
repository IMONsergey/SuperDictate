# Watch Capture UX Specification

Status: product and interaction specification  
Platforms: watchOS and Wear OS  
Priority: first wearable vertical slice

## 1. Purpose

The watch client exists to make capture faster than opening a phone while preserving trust and recording reliability.

It is not a miniature version of the phone application.

The primary watch experience must be understandable without onboarding:

- one obvious action starts recording;
- the recording state is unmistakable;
- one obvious action stops recording;
- the result survives without a network connection;
- the user knows whether the recording is local, transferring, processing or ready.

## 2. Primary interaction model

### 2.1 Idle screen

The default screen contains:

- current capture mode;
- one dominant record control;
- local queue indicator only when non-empty;
- discreet access to recent recordings;
- no dashboard clutter.

The record control must remain usable with reduced precision and while walking.

### 2.2 Start recording

Supported entry points:

- tap the main record control;
- watch complication or tile;
- supported hardware/action-button shortcut;
- platform voice shortcut or app intent where available;
- recent-mode shortcut.

Starting a recording requires exactly one intentional action after the user has granted permissions and completed initial setup.

Optional consent confirmation may add a second step for meeting modes, but solo quick thoughts must remain one-action capture.

### 2.3 Recording screen

The recording screen displays:

- persistent red recording indicator;
- elapsed time;
- selected mode;
- input-level or voice-activity feedback that does not resemble a decorative animation;
- stop control;
- marker control;
- pause control only when platform and session policy permit it.

The screen must avoid tiny controls and accidental side-by-side destructive actions.

### 2.4 Stop recording

Stopping creates a durable local artifact before any upload or processing action begins.

After stop:

1. haptic confirmation;
2. local finalization state;
3. success state once the local file is recoverable;
4. background transfer when possible;
5. status transitions visible in recent recordings.

The interface must not say “Saved” if only an in-memory buffer exists.

## 3. Haptic language

Haptics must remain consistent across the product.

| Event | Haptic meaning |
|---|---|
| Recording started | one strong confirmation |
| Marker added | one light confirmation |
| Recording paused | two light confirmations |
| Recording resumed | one medium confirmation |
| Recording safely stored locally | one success confirmation |
| Upload completed | optional subtle confirmation |
| Result ready | optional notification, user-configurable |
| Recoverable failure | warning pattern |
| Recording cannot continue | urgent failure pattern |

Haptics complement visible state; they never replace it.

## 4. Marker interaction

During recording the user can mark a moment without speaking a command.

Default marker types:

- important;
- task;
- decision;
- question.

The first version uses one marker action that creates an `important` marker. Advanced marker selection may be offered through a secondary gesture or a phone-side setting.

A marker stores:

- local marker identifier;
- offset from recording start;
- type;
- creation timestamp;
- optional short note added later on the phone.

Marker creation must work offline and must never interrupt audio capture.

## 5. Mode selection

The watch exposes a small set of pinned modes rather than the entire recipe library.

Default pinned modes:

- Quick thought;
- Meeting;
- Client corrections;
- Daily memory.

The phone configures:

- mode order;
- default mode;
- consent requirements;
- retention policy;
- processing recipe;
- whether pause is available;
- whether a mode creates memory candidates.

A user may start recording immediately with the last-used mode and change it after capture if necessary.

## 6. Complication and tile behavior

The complication or tile has one primary purpose: begin capture.

It may display:

- record icon when idle;
- red active state while recording;
- local queue count when files await transfer;
- processing indicator for the latest item;
- ready indicator only briefly or when actionable.

It must not display transcript content, private titles or meeting names on the watch face by default.

## 7. Offline-first behavior

The watch treats the phone and network as optional during capture.

Required behavior:

- recording starts without phone connectivity;
- chunks are written to local durable storage;
- metadata and markers are persisted alongside audio;
- finalization does not require connectivity;
- transfer resumes after interruption;
- duplicate transfers are idempotent;
- source audio is not deleted until durable receipt is confirmed;
- storage pressure is visible before the watch can no longer record.

The queue displays plain-language states:

- On this watch;
- Waiting for phone;
- Transferring;
- Uploaded;
- Processing;
- Ready;
- Needs attention.

## 8. Interruption behavior

### 8.1 Incoming call or system audio interruption

The client records the interruption event and follows platform rules.

Possible outcomes:

- recording continues;
- recording pauses and can resume;
- recording is finalized into a recoverable partial file.

The user is informed of the actual outcome. The application must not pretend continuity when audio is missing.

### 8.2 App backgrounding or wrist-down state

Expected background transitions must not stop capture when the platform permits continued recording.

The interface restores the active session when reopened.

### 8.3 Process termination or crash

Audio must be chunked or periodically checkpointed so the maximum expected loss is bounded.

On next launch:

- recover valid chunks;
- finalize a partial recording;
- label the interruption;
- offer upload or deletion;
- never discard the artifact silently.

### 8.4 Low battery

The user receives a warning before recording becomes unsafe.

When remaining energy crosses a critical threshold:

- create a durable checkpoint;
- stop accepting nonessential processing;
- prefer preserving audio over animation or transfer;
- finalize safely if continuation cannot be guaranteed.

### 8.5 Low storage

Before capture, estimate whether the requested session can start safely.

During capture:

- warn once at a meaningful threshold;
- avoid repeated alerts;
- finalize before filesystem exhaustion where possible.

### 8.6 Phone unavailable

The watch retains recordings and retries handoff later. Phone absence is not an error state unless watch storage is exhausted.

## 9. Accidental recording protection

The product must balance one-action capture with protection from accidental sessions.

Controls:

- immediate strong haptic on start;
- persistent visible state;
- optional auto-stop when no speech is detected for a configurable period, disabled by default for meetings;
- minimum-duration handling for recordings shorter than a configurable threshold;
- easy discard immediately after stop;
- no hidden background start;
- no start from an ambiguous passive gesture.

Recordings shorter than five seconds may be presented as possible accidents, but they are not deleted automatically.

## 10. Consent and visible recording

Meeting and interview modes can require consent confirmation.

Consent states:

- not required for a solo note;
- user confirmed participants were informed;
- consent reminder dismissed with an auditable choice;
- consent status unknown;
- recording prohibited by workspace policy.

The watch must always show an active recording indication. The application must not provide a stealth mode.

Optional spoken announcement or sound can be configured for environments where explicit audible notice is desired, subject to platform capability.

## 11. Recent recordings

The watch retains a compact recent list.

Each item shows:

- capture time;
- mode;
- duration;
- state;
- privacy-safe title or generic label;
- whether action is required.

Available actions:

- retry transfer;
- discard local copy after confirmation;
- add marker or short label;
- open on phone;
- replay only when policy permits and headphones/routing are safe.

Detailed editing belongs on the phone or desktop.

## 12. Result notification

Notifications are outcome-oriented.

Good examples:

- “Thought ready — 2 tasks found.”
- “Meeting ready — 3 decisions need review.”
- “Upload needs attention.”

Bad examples:

- “AI processing complete.”
- repeated progress notifications;
- transcript content on the lock screen by default.

Users configure notification privacy and whether completed results appear on the watch.

## 13. Accessibility

Required considerations:

- VoiceOver / TalkBack labels for all controls;
- no state communicated by color alone;
- scalable typography within watch constraints;
- strong contrast;
- controls usable with motor limitations;
- haptic alternatives and reduced-motion behavior;
- mode names that remain understandable when truncated;
- RTL and localization-safe layouts.

## 14. Privacy on the wrist

The watch is a highly visible surface.

Default privacy rules:

- no raw transcript on the watch face;
- no participant names in complications;
- no sensitive project title in notifications unless enabled;
- private recordings use generic labels in recent lists when wrist privacy is enabled;
- local audio is protected with platform data protection;
- authentication is required before destructive or sensitive actions where platform policy supports it.

## 15. Battery budget principles

During recording, priority order is:

1. preserve audio;
2. checkpoint metadata;
3. maintain clear state;
4. accept markers;
5. defer transfer;
6. defer nonessential animation and analysis.

Waveform rendering must be inexpensive. Full transcription does not run on the watch in the initial product.

## 16. First vertical slice acceptance criteria

The first watch release is successful only when all are true:

- a quick thought starts in one intentional action;
- recording works with the phone disconnected;
- a force-quit or interruption yields a recoverable artifact;
- stop creates a locally durable recording;
- the recording transfers later without duplication;
- the user sees accurate transfer and processing state;
- the phone displays the transcript and summary;
- a task marker created on the watch is preserved;
- source evidence remains accessible;
- deletion removes the local and server copy according to policy;
- the user can export their data;
- no stealth recording path exists.

## 17. Deferred features

Not required for the first slice:

- live transcription on watch;
- full transcript editing;
- speaker naming on watch;
- arbitrary AI chat;
- complex project management;
- continuous ambient listening;
- automatic recording based on location or calendar without a user action;
- watch-only account setup and billing.