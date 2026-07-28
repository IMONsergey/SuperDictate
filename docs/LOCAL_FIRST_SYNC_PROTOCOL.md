# Local-First Recording and Synchronization Protocol

Status: architecture and reliability specification  
Scope: watchOS, Wear OS, iOS, Android, macOS and backend ingestion

## 1. Reliability objective

A recording is valuable before it reaches the server.

The system must preserve a recoverable local artifact under:

- no network;
- phone disconnected from watch;
- process termination;
- application crash;
- temporary authentication failure;
- upload timeout;
- duplicate completion request;
- server restart;
- provider outage;
- low battery;
- storage pressure.

Cloud synchronization improves availability and processing, but it is not part of the critical path for preserving captured audio.

## 2. Identity model

Every capture receives identifiers before audio begins.

### 2.1 Client recording identifier

A globally unique identifier generated on the capture device.

Properties:

- stable for the lifetime of the recording;
- survives upload retries;
- survives watch-to-phone handoff;
- used as the primary idempotency boundary;
- never reused after deletion.

### 2.2 Asset identifier

Identifies one logical audio asset for a recording.

A recording may contain multiple assets because of:

- interrupted sessions;
- format migration;
- recovered partial audio;
- separate microphone tracks;
- imported media.

### 2.3 Chunk identifier

Identifies one immutable chunk of an asset.

A chunk records:

- zero-based sequence index;
- byte count;
- duration;
- checksum;
- format metadata;
- local persistence state;
- transfer state.

### 2.4 Upload operation identifier

Identifies one upload attempt or resumable upload session.

It is not the idempotency key. Several upload operations may exist for one recording while producing one server recording object.

### 2.5 Idempotency key

Derived from stable client identity and operation type.

Examples:

- create recording: `recording:{clientRecordingID}:create`;
- complete upload: `recording:{clientRecordingID}:complete:{manifestRevision}`;
- create marker: `recording:{clientRecordingID}:marker:{markerID}`;
- request processing: `recording:{clientRecordingID}:process:{recipeVersion}`.

The server stores results for an idempotency window long enough to cover realistic offline retries.

## 3. Local recording package

Each recording is persisted as a package or directory containing:

- manifest;
- immutable audio chunks;
- marker journal;
- recovery journal;
- optional waveform summary;
- checksums;
- migration version.

Example logical layout:

```text
recordings/<clientRecordingID>/
  manifest.json
  recovery.log
  markers.jsonl
  assets/<assetID>/
    000000.audio
    000001.audio
    000002.audio
```

The exact filesystem layout is platform-specific. The logical semantics are shared.

## 4. Manifest

The manifest contains:

- schema version;
- client recording identifier;
- recording descriptor;
- product policy snapshot;
- capture state;
- manifest revision;
- assets and chunks;
- markers;
- consent state;
- created, updated and finalized timestamps;
- transfer route;
- server recording identifier when known;
- deletion state;
- last recoverable error.

A manifest update uses atomic replacement where supported:

1. write temporary manifest;
2. flush file contents;
3. replace current manifest atomically;
4. flush parent directory when the platform exposes that capability.

## 5. Chunking strategy

Audio is persisted incrementally rather than held until stop.

Initial targets:

- chunks short enough to bound crash loss;
- chunks large enough to avoid excessive filesystem and request overhead;
- immutable once closed;
- independently checksummed;
- ordered by explicit sequence number.

The final chunk may be shorter.

A chunk is eligible for transfer only after:

- encoder finalized it;
- byte count is known;
- checksum is persisted;
- manifest references it.

## 6. Capture state

Shared local states:

- `open` — actively capturing or resumable;
- `finalizing` — encoder and manifest are closing;
- `finalized` — local source is durable;
- `queued` — eligible for transfer;
- `transferring` — at least one transfer is active;
- `uploaded` — server confirmed durable receipt;
- `processing` — server processing requested or active;
- `ready` — required processing artifacts available;
- `needsAttention` — user or client action required;
- `deletionPending`;
- `deleted`.

The UI may simplify these states but cannot report a later state without the associated invariant.

## 7. Critical state invariants

- `finalized` means all referenced chunks are recoverable locally.
- `uploaded` means the server has acknowledged the complete manifest and required objects.
- local source is not automatically deleted merely because all bytes were sent.
- `ready` means requested required artifacts exist, not merely that a job ended.
- `deleted` means the object is excluded from active retrieval.
- manifest revision increases for every material local mutation.
- a closed chunk never changes bytes.
- one recording may have only one active finalization operation.

## 8. Watch-to-phone handoff

The watch supports two routes:

### 8.1 Companion route

```text
Watch → Phone → Object Storage / API
```

Preferred when:

- phone is available;
- phone can use background transfer more efficiently;
- watch should conserve battery;
- mobile authentication is centralized on phone.

The phone receives:

- recording manifest;
- chunks;
- markers;
- checksums;
- original client identifiers.

The phone stores the package durably before acknowledging the watch.

The watch does not delete its source until companion durability is confirmed and local retention policy permits deletion.

### 8.2 Direct route

```text
Watch → Object Storage / API
```

Available where platform/network capability and product policy permit.

The same client recording identifier and server contract are used. Switching routes must not create duplicate server recordings.

## 9. Handoff acknowledgement levels

A generic “sent” state is insufficient.

Acknowledgement levels:

1. `receivedInMemory` — never sufficient for deletion;
2. `persistedOnCompanion` — companion has durable local package;
3. `uploadedToServer` — server has durable objects;
4. `serverManifestCommitted` — server accepted complete manifest;
5. `processingAccepted` — processing job created idempotently.

Each client exposes the highest confirmed level internally.

## 10. Upload sequence

Recommended sequence:

1. obtain or refresh authenticated session;
2. create server recording using client recording identifier;
3. receive upload intent or resumable session;
4. upload missing chunks directly to object storage;
5. verify local and remote checksum/ETag policy;
6. submit complete manifest with revision;
7. server validates chunk set, order, sizes and checksums;
8. server atomically marks recording upload complete;
9. request processing idempotently;
10. retain or delete local source according to policy.

The API server does not proxy large audio bytes unless required by a deployment mode.

## 11. Resume behavior

On retry, the client asks which objects are already present or uses resumable-session state.

The client must not blindly resend the entire recording when only one chunk failed.

Resume metadata includes:

- upload operation identifier;
- completed chunk identifiers;
- byte offset where supported;
- manifest revision;
- credential expiry;
- last server acknowledgement.

Expired credentials create a new upload operation without changing recording identity.

## 12. Queue behavior

Queue entries have:

- recording identifier;
- priority;
- creation time;
- next eligible attempt;
- attempt count;
- idempotency key;
- transfer route;
- last error;
- state.

Scheduling principles:

- user-triggered short notes before bulk imports;
- finalized recordings only;
- bounded concurrency;
- network-aware and battery-aware execution;
- exponential backoff with jitter;
- explicit retry-now action;
- permanent failures do not spin;
- authentication failures pause related entries until credentials refresh.

## 13. Retry classification

### Recoverable

Examples:

- timeout;
- network unavailable;
- temporary server error;
- expired signed URL;
- rate limit;
- companion unavailable;
- background execution ended.

### Requires user action

Examples:

- account signed out;
- quota exhausted;
- workspace access revoked;
- insufficient local storage;
- cellular upload disabled by setting.

### Permanent

Examples:

- source chunk checksum mismatch that cannot be recovered;
- unsupported/corrupt format;
- recording prohibited by policy;
- object deleted intentionally;
- schema version too new for the current client without a migration path.

Permanent failure preserves available source and diagnostic metadata until the user decides what to do.

## 14. Backoff

Default retry schedule uses capped exponential backoff plus bounded jitter.

Properties:

- attempt count persisted;
- app restart does not reset backoff;
- manual retry may bypass the timer once;
- server-provided `Retry-After` takes precedence;
- authentication refresh has a separate retry budget;
- background scheduler may delay further according to platform policy.

## 15. Reconciliation

Clients periodically reconcile local and server state.

Rules:

- server identity is mapped by client recording identifier;
- server `uploaded` wins only after manifest validation;
- a local source may remain after server deletion if deletion propagation failed; it must be quarantined from upload until resolved;
- user edits use revisions and conflict metadata;
- markers merge by stable marker identifier;
- duplicate chunks are recognized by identity and checksum;
- a later manifest revision never removes a chunk without an explicit deletion or supersession record;
- state regressions are recorded, not silently ignored.

## 16. Conflict examples

### Same recording uploaded by watch and phone

The server returns the existing recording for the same client identifier. Missing chunks are accepted; duplicates are ignored after checksum validation.

### Phone edited title while offline

Metadata uses revision or field-level merge rules. Source audio identity is unaffected.

### User deleted on phone while watch was offline

Deletion tombstone blocks future upload. On reconnect, watch removes or archives the local package according to policy and displays the deletion result.

### Processing completed before phone sync state updated

Reconciliation can advance local state directly to ready after server verification.

## 17. Deletion tombstones

A deletion tombstone contains:

- recording identifier;
- deletion request identifier;
- requested timestamp;
- origin device;
- scope;
- server acknowledgement state;
- expiration according to synchronization policy.

Tombstones prevent an offline device from resurrecting deleted recordings.

## 18. Quota exhaustion

Cloud quota exhaustion is a queue condition, not a capture failure.

Behavior:

- local capture continues;
- manifest marks processing blocked by quota;
- optional upload behavior follows plan and storage policy;
- user receives a clear state;
- queue resumes after renewal, top-up or plan change;
- no repeated paid operation is attempted without authorization.

## 19. Storage pressure

Cleanup order must preserve user value:

1. temporary processing files;
2. acknowledged duplicate transfer artifacts;
3. server-confirmed source files eligible under retention policy;
4. cached waveforms and previews;
5. never silently delete the only recoverable source.

If space is insufficient for a new safe recording, the application refuses to start and explains the required action.

## 20. Schema migration

Local package schemas are versioned.

Migration rules:

- migrations are forward-only and tested;
- create backup or recoverable checkpoint before destructive migration;
- unknown future schema is opened read-only or blocked safely;
- migration failure preserves original package;
- server accepts supported prior manifest versions or returns an explicit upgrade error.

## 21. Observability

Operational events contain no transcript content.

Useful fields:

- recording identifier;
- source platform;
- package schema version;
- chunk count and total bytes;
- queue state;
- route;
- attempt count;
- error code;
- acknowledgement level;
- duration in each state;
- recovery outcome.

## 22. Required fault-injection tests

- kill process during active chunk write;
- kill process during manifest replacement;
- interrupt finalization;
- disconnect watch during handoff;
- expire upload URL mid-chunk;
- duplicate create/complete requests;
- corrupt one local chunk;
- server accepts chunk but response is lost;
- server restart before manifest commit;
- token revoked during upload;
- quota exhausted after upload but before processing;
- delete on phone while watch offline;
- low storage during recording;
- app upgraded with queued old-schema recordings.

## 23. First implementation slice

The first code implementation provides:

- shared manifest and chunk models;
- deterministic queue model;
- idempotent enqueue;
- persisted attempt/backoff metadata;
- transfer route;
- acknowledgement level;
- recoverable versus permanent failure classification;
- protocols for manifest storage and transport;
- unit tests for deduplication, retry and recovery.

Platform-specific filesystem and networking adapters follow in separate PRs.