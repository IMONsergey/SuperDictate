# Cross-platform delivery roadmap

This roadmap keeps the current macOS product operational while adding a mobile, wearable and cloud recording vertical slice.

## Delivery rules

- Never commit feature work directly to `main`.
- One focused branch and pull request per stage.
- Preserve current macOS local dictation behavior until equivalent regression coverage exists.
- Every recording mutation is idempotent.
- Every device writes audio locally before upload.
- Upload, transcription and structuring are separately observable stages.
- Do not advertise unlimited usage until real per-minute cost and abuse data exist.

## Foundation PR sequence

### PR 0 — project baseline

Existing branch: `audit/project-baseline`

- finish factual repository audit;
- document current architecture, build, CI and release behavior;
- establish source-of-truth project state;
- merge before runtime restructuring where practical.

### PR 1 — cross-platform contract and architecture

Branch: `product/cross-platform-foundation`

- product definition;
- native-client ADR;
- initial OpenAPI contract;
- contract linting in CI;
- staged delivery roadmap.

No runtime behavior changes.

### PR 2 — Apple shared core extraction

Suggested branch: `foundation/apple-shared-core`

- create `SuperDictateCore` Swift package;
- define recording state machine;
- define platform-neutral recording metadata;
- define processing state and retry policy;
- introduce protocols for recorder, local store, uploader and API client;
- wrap existing macOS behavior with adapters;
- add unit tests before moving production logic.

Acceptance:

- current macOS self-tests remain green;
- no bundle ID, entitlement, storage-path or release change;
- state-machine tests cover interrupted and retried recordings.

### PR 3 — backend contract skeleton

Suggested branch: `backend/recording-api-skeleton`

- TypeScript/Hono API;
- Supabase authentication verification;
- recording endpoints from OpenAPI;
- idempotency storage;
- signed upload URL generation for Cloudflare R2;
- database migrations;
- structured request logging;
- local development environment.

Acceptance:

- OpenAPI contract tests pass;
- duplicate idempotency keys return the original result;
- API server never proxies complete audio files.

### PR 4 — processing queue and transcription worker

Suggested branch: `backend/transcription-pipeline`

- queue jobs after upload completion;
- faster-whisper worker;
- VAD and language detection;
- transcript persistence;
- retry and dead-letter behavior;
- per-recording processing events;
- usage ledger measured in audio milliseconds.

Acceptance:

- repeated jobs do not duplicate transcripts or usage charges;
- failed jobs expose a stable error code;
- a test recording reaches `ready` end to end.

### PR 5 — iOS recorder MVP

Suggested branch: `app/ios-recorder-mvp`

- SwiftUI iPhone application;
- microphone permission flow;
- crash-safe local recording;
- pause and resume;
- background/resumable upload;
- recording mode selection;
- local queue and processing status;
- transcript and summary result screen.

Acceptance:

- airplane-mode recording succeeds;
- upload resumes after connectivity returns;
- terminating the application does not silently delete completed audio.

### PR 6 — watchOS capture MVP

Suggested branch: `app/watchos-capture-mvp`

- one-tap start and stop;
- visible recording indicator;
- haptic confirmations;
- offline queue;
- important-moment markers;
- complication and quick action;
- transfer through phone when available;
- direct network upload fallback where supported;
- compact processing status and result.

Acceptance:

- watch records without the phone being actively open;
- a recording survives temporary disconnection;
- the user can always determine whether recording is active.

### PR 7 — structured processing

Suggested branch: `backend/structured-results`

- summaries;
- tasks and owners;
- decisions;
- unresolved questions;
- client-correction template;
- schema-validated LLM outputs;
- prompt and model version tracking.

Acceptance:

- invalid model output cannot corrupt persisted data;
- every result records prompt version, model and processing run;
- reprocessing creates a new version rather than overwriting history silently.

### PR 8 — synchronized macOS library

Suggested branch: `app/macos-synced-library`

- preserve current push-to-talk mode;
- add authenticated cloud library;
- show mobile and watch recordings;
- transcript search and review;
- opt-in cloud processing;
- clear separation between local-only and synchronized recordings.

### PR 9 — Android recorder MVP

Suggested branch: `app/android-recorder-mvp`

- Kotlin and Jetpack Compose;
- Room local persistence;
- foreground recording service;
- WorkManager upload queue;
- generated API client;
- same recording modes and processing states as iOS.

### PR 10 — Wear OS capture MVP

Suggested branch: `app/wearos-capture-mvp`

- native wearable capture;
- tile and complication;
- haptics and visible recording state;
- offline queue;
- Data Layer bridge plus direct-upload fallback;
- compact result screen.

## Product expansion after the vertical slice

- speaker diarization;
- project memory and semantic search;
- custom vocabulary;
- multilingual translation;
- reminders and calendar actions;
- Telegram, email, Notion and webhook integrations;
- team workspaces;
- billing and minute quotas;
- web library and administration;
- Windows desktop client;
- optional local transcription packs;
- end-to-end encrypted private vault mode.

## Metrics required from the first 100 users

- recorded minutes per active user;
- median and p95 recording length;
- upload completion rate;
- time from stop to ready result;
- transcription real-time factor;
- GPU cost per audio hour;
- structuring cost per recording;
- failed or retried job rate;
- audio retained per user;
- recordings opened after processing;
- tasks or exports created from a result;
- seven-day and thirty-day retention.

## Explicitly deferred

- custom watch hardware;
- live continuous ambient capture;
- live full transcript on a watch;
- social/public recordings;
- one UI framework for every platform;
- premature Kubernetes deployment;
- unlimited plans without quotas and abuse controls.
