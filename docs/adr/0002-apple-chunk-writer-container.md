# ADR 0002: Apple recording chunks use crash-safe immutable containers

- Status: Accepted
- Date: 2026-07-29
- Owners: SuperDictate product and engineering

## Context

SuperDictate's next Apple runtime step needs local audio to survive app kills, crashes, power loss and offline operation before any upload or transcription work begins. The current macOS runtime keeps a temporary raw Float32 recovery journal for a single in-memory capture. That is useful as a fallback, but it is not a cross-device recording package, does not rotate immutable chunks, and does not give sync/recovery code a manifest-backed source of truth.

The chunk layer must work on macOS, iOS and watchOS. It must avoid custom codecs, protect source bytes from silent deletion, provide checksums, and distinguish full, partial, corrupt, missing and orphaned chunks.

## Spike

Evaluated native container options for the first Apple adapter:

- CAF with Linear PCM: strong Apple-platform support, simple sample-accurate finalization, predictable recovery semantics, larger files, low codec complexity.
- CAF with compressed audio: still Apple-native, better file size, but more encoder/finalization state to validate under crash and watchOS constraints.
- M4A/AAC per chunk: efficient and broadly portable, but each chunk depends on container finalization and encoder state that is harder to reason about during process death.
- Raw PCM plus sidecar metadata: simplest writes, but weaker interoperability and more custom container responsibility.

## Decision

Build the A1 writer as a container-neutral durable file layer and default its finalized extension to `.caf`. The first AVFoundation adapter should prefer CAF plus Linear PCM until device tests prove a compressed format can meet the same crash-recovery, CPU, battery, seek, checksum and transcription requirements.

The writer owns ordering and durability, not encoding:

- create the recording package before writing bytes;
- write active chunks with a temporary suffix;
- flush and fsync before close;
- rename to the final chunk name only after close succeeds;
- compute SHA-256 over the finalized bytes;
- append journal events for every recovery-critical transition;
- atomically commit the chunk descriptor to `manifest.json`;
- never mark a chunk durable in the manifest before flush, close and checksum complete.

## Consequences

### Positive

- A crash after final chunk close but before manifest commit can be repaired from the journal and chunk file.
- A crash before close leaves a partial file that recovery quarantines instead of silently deleting.
- Upload and sync code can trust manifest chunks as immutable source files.
- AVFoundation, watchOS and iOS adapters can share the same package semantics while choosing platform-specific encoding details later.

### Negative

- CAF plus PCM is larger than AAC and will need storage-pressure tests on Watch.
- The writer cannot validate audio container semantics until the AVFoundation adapter writes real CAF data.
- Recovery code must preserve suspicious bytes, so disk usage may temporarily grow through quarantine.

## Guardrails

- Do not invent a custom codec or unversioned sidecar format.
- Do not auto-delete partial, orphan or checksum-mismatched bytes during recovery.
- Do not log transcript text, inferred content or full private paths in journal messages.
- Treat quota exhaustion as a local processing/upload block, not as permission to lose source audio.
- Format changes require tests that cover crash recovery, chunk rotation, checksum validation, transcription handoff and watchOS resource limits.
