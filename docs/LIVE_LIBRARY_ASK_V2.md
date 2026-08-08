# Live Library and evidence Ask v2

Status: production integration note.

## Product result

The native SuperDictate shell now uses one local evidence foundation for two user jobs:

```text
Library -> find/open a recording
Ask     -> find/open the exact supporting source fragment
```

Both remain local-first and work without an account or cloud request.

## Durable Library ownership

The visible product process opens `JSONSuperDictateLibraryStore` under SuperDictate Application Support.

The durable archive owns:

- recordings;
- verified tasks when available;
- local memory/evidence documents.

Runtime capture/transcription health still comes from the background agent through `AgentRuntimeState`.

The UI combines these layers instead of making filesystem or ASR implementation details part of product state.

## Legacy bridge

The old rolling `recentTranscriptEntries` archive is still observed because existing installations already contain user history there.

During the transition:

1. the shared `SuperDictateLegacyHistoryMigrator` creates the same stable recording identities used by the Library migration;
2. only missing recordings/evidence documents are added to the durable Library;
3. richer existing durable metadata is never replaced by poorer legacy metadata;
4. unknown source dates remain `nil` rather than being fabricated;
5. known legacy transcription duration is preserved;
6. Library write/read failure falls back to the runtime snapshot and never blocks dictation.

The final architecture should have the background agent persist every successful dictation directly into the Library. The UI-side legacy bridge can then be removed after migration coverage proves safe.

## Disk-sync policy

The product window does not re-read the Library every 750 ms.

A reload/sync is scheduled when:

- the product window first opens;
- it is explicitly shown again;
- the set of runtime recording IDs changes.

Concurrent refreshes are coalesced. If new history appears during an in-flight Library operation, one follow-up pass is guaranteed after the current task releases its handle.

## Native Library search

Library uses native SwiftUI `.searchable`.

Current search semantics are intentionally described as local lexical search, not semantic AI.

The search index is the same `SuperDictateLocalMemoryIndex` used by Ask. A query returns recording IDs and the Library keeps its normal native list presentation rather than switching to dashboard/search cards.

If durable memory documents are temporarily unavailable, Library can build transient evidence documents from the recordings already in the snapshot.

## Evidence-first Ask

Ask is no longer a fake chat placeholder.

Current behavior:

- deterministic local retrieval only;
- global or recording-scoped documents;
- exact source excerpt;
- source recording identity;
- speaker when known;
- timestamp when known;
- RU/EN copy and accessibility labels;
- no evidence => explicit no-evidence state;
- clicking evidence opens the actual recording in Transcript.

No generative model is called. This establishes the UI/provenance contract before synthesis is added.

A future answer model must sit **after** retrieval and preserve citations; it must not replace or bypass this evidence layer.

## Privacy

No new network access is introduced.

The Library index remains a private rebuildable local product index. Errors may log operation state/error descriptions but must never log transcript contents.

## Next persistence step

Move successful-dictation persistence from the visible-process migration bridge into the background agent after transcription success.

Acceptance criteria for that move:

- Library write happens independently of whether the main window is open;
- failed Library write never destroys transcript or insertion result;
- stable recording ID is created once and reused across Library/evidence/tasks;
- source metadata is written only when actually known;
- migration from legacy history remains idempotent;
- no low-level audio/ASR invariants are changed.
