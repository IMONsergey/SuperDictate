# SuperDictate — cross-platform product definition

## Decision

SuperDictate becomes one product across desktop, phone and wearable devices rather than a standalone macOS utility or a watch-only recorder.

The product must support:

- macOS;
- iOS;
- watchOS;
- Android;
- Wear OS;
- web account/library interface;
- Windows after the mobile and wearable recording flow is stable.

The existing macOS application remains a first-class local dictation client. New applications add long-form recording, synchronization, transcription, structured memory and wearable capture.

## Product promise

Press once, speak or record a meeting, and receive a trustworthy searchable result:

- verbatim transcript;
- short summary;
- decisions;
- tasks and owners;
- client corrections;
- important moments;
- project assignment;
- export or follow-up action.

A recording must never depend on a live network connection. Every client saves locally first, then uploads and processes asynchronously.

## Platform roles

### macOS

- preserve current push-to-talk local dictation;
- long-form meeting recorder;
- local transcription where hardware allows;
- searchable recording library;
- global shortcut and quick history;
- desktop review and editing workspace.

### iOS and Android

- primary account and library application;
- one-tap recording;
- background upload;
- transcript, summary, tasks and search;
- project and template management;
- device, storage and privacy settings;
- bridge for watch connectivity when required.

### watchOS and Wear OS

- one-tap recording with explicit visible state;
- haptic start, marker and stop confirmation;
- offline local queue;
- complication/tile and quick action;
- mark an important moment during recording;
- select recording mode before start;
- show upload and processing status;
- show compact result: summary, tasks, decisions;
- hand off the full result to the phone.

### Web

- account and billing;
- searchable library;
- transcript review;
- project/team administration;
- export and integration setup;
- support tooling and operational diagnostics.

## Recording modes

1. **Quick thought** — short personal note, aggressive silence trimming, concise result.
2. **Dictation** — punctuation and formatting optimized for immediate text output.
3. **Meeting** — long-form audio, speaker separation, decisions and tasks.
4. **Client corrections** — extract every requested change, ambiguity and approval.
5. **Interview** — questions, answers, quotes and topics.
6. **Daily memory** — personal timeline with semantic search.
7. **Custom template** — user-defined processing instructions and output schema.

## Feature set

### Capture

- local-first recording;
- pause/resume;
- important-moment markers;
- pre-recording mode selection;
- automatic segmentation for long files;
- crash-safe recording finalization;
- resumable upload;
- configurable audio retention;
- visible recording indicator on all devices.

### Intelligence

- transcription;
- punctuation and paragraphing;
- language detection;
- multilingual transcription and translation;
- speaker diarization;
- custom vocabulary and names;
- summaries at several lengths;
- tasks, owners and deadlines;
- decisions, risks and unresolved questions;
- client corrections and approvals;
- semantic search across recordings;
- question answering over one recording, project or full history;
- automatic project classification;
- duplicate and repeated-topic detection.

### Actions

- copy formatted text;
- share transcript or summary;
- create reminders and calendar events;
- export Markdown, TXT, PDF, DOCX and SRT/VTT;
- send to Telegram, email, Notion and webhooks;
- create tasks in connected systems;
- produce a follow-up email or meeting protocol.

### Trust and privacy

- explicit consent guidance before meeting recording;
- clear always-visible recording state;
- local save before network operations;
- encrypted transport and encrypted object storage;
- configurable automatic audio deletion;
- separate retention policy for audio and text;
- account export and complete deletion;
- audit trail for uploads, processing and deletion;
- no training on private recordings by default.

## Architecture

```text
Apple clients                     Android clients
macOS / iOS / watchOS             Android / Wear OS
Swift + SwiftUI                    Kotlin + Compose
        |                                  |
        +---------- generated API clients--+
                           |
                    OpenAPI contract
                           |
                 TypeScript/Hono API
                           |
       +-------------------+-------------------+
       |                   |                   |
Supabase Auth/Postgres  Object storage      Job queue
                       Cloudflare R2       Postgres/Redis
                                               |
                                      GPU transcription workers
                                      faster-whisper / diarization
                                               |
                                      structured processing workers
                                               |
                                      transcript, summary, tasks
```

## Code-sharing strategy

Do not force one UI framework across Apple Watch and Wear OS.

### Shared within Apple platforms

Create a Swift package named `SuperDictateCore` for:

- recording state machine;
- local metadata model;
- upload queue;
- API models and generated client;
- retry policy;
- feature flags;
- processing status;
- privacy and retention settings.

Platform-specific adapters remain separate for audio sessions, background execution, watch connectivity, shortcuts and UI.

### Shared within Android platforms

Create Kotlin modules for:

- domain models;
- recording state machine;
- Room persistence;
- WorkManager upload queue;
- generated API client;
- processing status and feature flags.

Android and Wear OS share domain modules while keeping device-specific capture and UI adapters.

### Shared across all platforms

- OpenAPI specification;
- event names and analytics schema;
- database migrations;
- processing schemas;
- template definitions;
- feature flags;
- test fixtures;
- product copy source where practical.

## Repository direction

The repository will evolve toward:

```text
apps/
  macos/
  ios/
  watchos/
  android/
  wearos/
  web/
packages/
  apple-core/
  android-core/
  api-contract/
  processing-schemas/
services/
  api/
  transcription-worker/
  processing-worker/
infra/
  database/
  storage/
  deployment/
docs/
```

The existing macOS source must be migrated incrementally. It must not be deleted or destabilized merely to obtain a neat monorepo structure.

## Core data model

- `users`
- `devices`
- `projects`
- `recordings`
- `recording_segments`
- `uploads`
- `transcripts`
- `speakers`
- `markers`
- `processing_runs`
- `summaries`
- `tasks`
- `decisions`
- `templates`
- `exports`
- `retention_policies`
- `usage_ledger`

Every recording and processing run needs an immutable identifier and idempotency key. Retried uploads or workers must not create duplicate transcripts or charges.

## Initial delivery boundary

The first usable cross-platform slice is deliberately narrower than the complete product:

1. iPhone records audio locally.
2. Apple Watch starts/stops a recording and keeps an offline queue.
3. Audio uploads through a resumable background transfer.
4. The server transcribes and produces summary, tasks and decisions.
5. iPhone and watch show processing status.
6. macOS can read the synchronized result without breaking current local dictation.

Android and Wear OS follow the same API contract after this vertical slice proves the model.

## Non-goals for the first slice

- continuous always-on recording;
- covert recording;
- live transcription on the watch;
- full editing on a watch display;
- custom wearable hardware;
- social feed or public recording marketplace;
- one-framework UI abstraction that weakens native background recording.
