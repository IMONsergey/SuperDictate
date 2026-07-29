# SuperDictateCore

Shared domain package for macOS, iOS and watchOS clients.

## Responsibilities

- recording modes and source-platform identifiers;
- recording metadata and markers;
- recording lifecycle state machine;
- upload and processing boundaries;
- retry semantics;
- JSON-backed recording manifests and upload queue stores;
- crash-safe immutable chunk writing;
- append-only recovery journaling and package recovery classification;
- Apple audio capture/session coordination boundaries;
- AVFoundation PCM-to-CAF chunk encoding and tap source boundaries;
- platform-neutral domain tests.

## Explicitly outside this package

- `AVAudioSession` and microphone permissions;
- background transfer implementation;
- WatchConnectivity;
- UI and haptics;
- authentication token storage;
- concrete API transport;
- transcription engines.

Audio-session, UI, networking and transcription concerns must be provided by platform adapters. File-system persistence lives here only where it is platform-family domain logic: recording packages, manifests, immutable chunks, upload queues and recovery results. This keeps capture durability testable before AVFoundation, WatchConnectivity or background transfer adapters are wired in.

## Recording package layout

`ChunkFileWriter` stores local recordings under the same root used by `JSONRecordingManifestStore`:

```text
recordings/<client-recording-id>/
  manifest.json
  recovery-journal.jsonl
  chunks/
    <asset-id>__000000__<chunk-id>.caf
  quarantine/
```

Chunks are immutable after close. Active chunks use the configured temporary suffix, are flushed and closed before the final rename, then the manifest is atomically updated. Recovery scans the manifest, journal, finalized chunk files and partial files; it recovers closed orphan chunks, quarantines partial or corrupt files, and marks the manifest `needs_attention` when source bytes require user-visible handling.

The default chunk policy targets 20 second chunks, allows up to 30 seconds per chunk, uses SHA-256 checksums and the `.caf` extension. The writer is container-neutral: AVFoundation adapters supply encoded bytes and timing metadata, while this package enforces durable ordering and recovery semantics.

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
