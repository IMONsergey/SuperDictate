# SuperDictateCore

Shared domain package for macOS, iOS and watchOS clients.

## Responsibilities

- recording modes and source-platform identifiers;
- recording metadata and markers;
- recording lifecycle state machine;
- upload and processing boundaries;
- retry semantics;
- platform-neutral domain tests.

## Explicitly outside this package

- `AVAudioSession` and microphone permissions;
- file-system implementation;
- background transfer implementation;
- WatchConnectivity;
- UI and haptics;
- authentication token storage;
- concrete API transport;
- transcription engines.

Those concerns must be provided by platform adapters. This keeps the state machine deterministic and testable across macOS, iPhone and Apple Watch.

## Run tests

```bash
swift test --package-path packages/apple-core
```

## Integration direction

Apple applications should own a `RecordingStateMachine`, persist the current recording descriptor and local audio URL, then translate platform callbacks into `RecordingEvent` values.

Example flow:

```text
microphone started      -> start
user pauses             -> pause
user resumes            -> resume
user stops              -> stop
file safely finalized   -> finalized
background upload starts-> uploadStarted
upload progress         -> uploadProgress
server accepts upload   -> uploadCompleted
worker status changes   -> processingChanged
result is ready          -> completed
```

Platform adapters must persist enough information to reconstruct the current state after a process termination. The state machine itself intentionally does not perform I/O.
