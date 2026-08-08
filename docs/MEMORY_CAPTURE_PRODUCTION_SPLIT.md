# Memory Capture production split

Status: implementation lab split contract, 2026-08-08.

`foundation/capture-kind-v2` is intentionally a development lab, not a future
single merge target. It combines schema exploration, source-package durability,
recovery and tests so invariants can be designed together before they are sliced
back into short production PRs from current `main`.

## Why this branch must not merge whole

The lab spans product schema, POSIX storage, hashing, crash recovery and source
identity. Merging all of that in one PR would make compiler/runtime regressions
hard to isolate and would recreate the old stacked-R&D problem that the current
Mac production spine was designed to remove.

## Production slice A — capture kind

Only:

- `SuperDictateCaptureKind`;
- optional `SuperDictateRecording.captureKind`;
- `effectiveCaptureKind` legacy fallback;
- backward-Codable tests.

No storage or runtime behavior.

Acceptance:

- old Library JSON decodes unchanged;
- new recordings default to `instantDictation`;
- no primary-navigation changes.

## Production slice B — Memory source package

Only:

- dual-track source/format/chunk descriptors;
- explicit Memory package lifecycle;
- private package store;
- actor-isolated manifest mutations;
- storage and malicious-JSON tests.

No AVFoundation or ScreenCaptureKit adapter yet.

Acceptance:

- 0700 package directories / 0600 manifests;
- atomic manifest replacement;
- symlink/non-regular file rejection;
- manifest path bound to source + sequence + chunk UUID;
- external adapters cannot call raw `saveManifest`;
- microphone and system mutations cannot race load-modify-save.

## Production slice C — chunk durability and recovery

Only:

- encoding-neutral CAF chunk committer;
- fsynced recovery journal;
- prepared-before-rename invariant;
- SHA-256 verification;
- quarantine and conservative package recovery;
- fault-oriented tests.

Acceptance:

- invalid metadata/container/size fail before rename;
- finalized source bytes are never silently deleted after rename;
- manifest append failure leaves a recoverable orphan;
- orphan reattachment requires durable journal metadata;
- undocumented/partial/corrupt source is quarantined;
- checksum/missing-source corruption can downgrade a ready package to
  integrity `needsAttention` only through the Core recovery layer;
- a torn final JSONL line is tolerated, while corruption in the middle is fatal.

## Production slice D — native audio adapters

Only after A-C are merged and green:

- AVFoundation microphone writer;
- ScreenCaptureKit system-audio writer;
- independent source clocks mapped to the package session timeline;
- chunk rotation/backpressure;
- permission gating that applies only to Memory Capture system audio.

Instant Dictation remains on the existing mic-only path.

## Production slice E — evidence processing

Only after durable dual-track capture is proven:

- offline transcription handoff;
- diarization on remote/system track where useful;
- local-user identity from microphone track;
- speaker directory assignments;
- evidence timeline;
- summary/task generation over evidence.

## Source-of-truth rule

The Memory package is authoritative for source audio. `library/index.json` is a
rebuildable product index and must never become the only copy of recording source
metadata or bytes.
