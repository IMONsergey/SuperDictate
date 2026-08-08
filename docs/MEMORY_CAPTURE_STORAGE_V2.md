# Memory Capture storage v2

Status: production contract prepared from current SuperDictate architecture plus the useful crash-safety findings from the archived chunk-writer R&D. No old cross-platform manifest/sync implementation is being merged.

## Product boundary

Instant Dictation and Memory Capture share recording identity and ASR infrastructure but have different source-retention needs.

- **Instant Dictation:** source audio is ephemeral by default; crash recovery preserves enough audio to avoid losing the dictation.
- **Memory Capture:** source audio is a durable local asset until the user explicitly deletes it or a future retention policy says otherwise.
- **Import:** source bytes are user-provided and must never be silently deleted as a side effect of transcription/indexing failure.

`SuperDictateCaptureKind` is the product discriminator for these lifecycle rules.

## Package layout target

A memory recording owns one private package under Application Support keyed by the same durable recording UUID used by Library/evidence:

```text
recordings/<recording-id>/
  manifest.json
  chunks/
    <sequence>__<chunk-id>.caf
  quarantine/
  recovery-journal.jsonl
```

Exact filenames are implementation detail; the invariants are not.

## Chunk durability order

A chunk is not durable just because bytes exist.

Required transition:

1. create package/manifest before source writes;
2. open a private `*.partial` chunk with `O_NOFOLLOW`;
3. write encoded audio bytes;
4. periodically flush according to policy;
5. `fsync` before close;
6. close the container successfully;
7. atomically rename partial → immutable final filename;
8. synchronize the containing directory;
9. compute SHA-256 over finalized bytes;
10. atomically commit the verified chunk descriptor to `manifest.json`.

Manifest must never claim a chunk is durable before steps 5–9 succeed.

## Container decision

First production adapter should use Apple-native CAF. Start with Linear PCM for the reliability spike because crash/finalization behavior is simpler to reason about than compressed container state. AAC/compressed CAF can be evaluated only after real device tests cover CPU, battery, size, seek, crash recovery and transcription handoff.

Do not invent a custom audio codec.

## Recovery semantics

- final verified chunk + missing manifest row → recover descriptor, do not discard bytes;
- partial chunk → quarantine, do not silently delete;
- checksum mismatch → quarantine + `needsAttention`;
- manifest missing/corrupt while chunks exist → preserve package and surface recovery;
- corrupt trailing journal line after process death → ignore only the incomplete tail when earlier events are valid;
- low storage → block/stop safely, never treat pressure as permission to destroy source audio.

## Single-writer rule

The background agent owns recording-package writes just as it owns the durable Library writer. Visible SwiftUI processes are readers/controllers only.

This avoids cross-process read-modify-write races and lets one actor serialize package state transitions.

## Privacy

- package directories `0700`;
- files `0600`;
- no symlink-following on sensitive opens;
- no transcript text, inferred content or full private paths in journal/diagnostic messages;
- source-audio deletion must be explicit and independent from deleting a recent-list row.

## Integration order

1. durable runtime recording UUID + capture date;
2. pending journal v2 preserves UUID/date through crash;
3. `SuperDictateCaptureKind` lands;
4. local package manifest + immutable chunk writer;
5. AVFoundation CAF adapter;
6. memory-session command/UI;
7. transcription/evidence handoff from finalized chunks;
8. optional speaker diarization/templates/tasks;
9. only then sync/export policies.

## Non-goal

Do not revive the previous cross-platform Apple manifest/sync stack wholesale. The useful R&D is crash/durability behavior. Production types must fit the current `SuperDictateCore`, current private Library store and current Mac release spine.
