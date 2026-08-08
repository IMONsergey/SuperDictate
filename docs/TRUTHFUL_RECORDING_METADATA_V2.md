# Truthful recording metadata v2

Status: production migration note.

## Product invariant

`SuperDictateRecording.durationSeconds` means source-audio duration only.

ASR/transcription processing time is operational performance metadata and must never be presented as recording length.

Likewise, `createdAt` is source capture chronology. If an older history row does not know when audio was captured, the product keeps it `nil` rather than substituting migration time, file time, or the current date.

## Legacy behavior

Pre-metadata history rows know:

- transcript text;
- optional ASR processing duration.

They do not know:

- source recording UUID;
- capture timestamp;
- source-audio duration.

Their durable Library projection therefore uses:

- deterministic text + duplicate-occurrence fallback UUID;
- `createdAt = nil`;
- `durationSeconds = nil`.

## Metadata-rich runtime rows

The migration contract also accepts optional real runtime metadata:

- `recordingID`;
- `createdAt`;
- `sourceAudioDurationSeconds`.

When present, these values are preserved. `transcriptionDurationSeconds` stays separate and is never copied into audio duration.

Explicit runtime UUID rows do not advance the duplicate counter used by fallback legacy IDs. Adding a new metadata-rich row therefore cannot silently renumber existing legacy identities.

## Repair of already-written Library rows

Earlier product builds could persist ASR processing duration in the Library recording-duration field.

The existing agent-owned startup merge performs a narrow repair only when a durable row:

1. has an ID that exactly matches the deterministic legacy text/occurrence identity;
2. has no capture date;
3. has a non-nil duration.

Only that duration is reset to unknown. Real runtime UUID rows are excluded. Legacy fallback rows enriched with a real capture date are excluded.

The repair is counted as a merge change so the existing single writer atomically persists the corrected archive even when no new history rows are added.

## Follow-up

The next runtime slice gives every new successful in-session dictation a real UUID and capture timestamp and carries the actual captured audio duration through history, live projection and the single-writer Library path. Pending crash-recovery audio remains backward-compatible until the versioned journal-header migration lands.
