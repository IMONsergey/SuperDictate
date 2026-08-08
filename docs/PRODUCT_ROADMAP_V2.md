# SuperDictate product roadmap v2

Status: execution plan.

Last reviewed: 2026-08-08.

## Product thesis

SuperDictate should become the best native voice layer on the Mac, with two deliberately separate but shared jobs:

1. **Instant Dictation** — press, speak, receive clean text in the current app with almost no interface.
2. **Memory Capture** — record a meeting/thought/conversation and turn it into a trustworthy recording detail with summary, transcript, tasks and scoped Ask.

They share audio, speech models, language settings, corrections, snippets, storage policy and search. They must not share all UI. Quick dictation stays nearly invisible; memory/review gets a lightweight native window.

## Differentiation

SuperDictate should not compete by showing more AI controls.

The differentiated combination is:

- software-native capture with no dedicated hardware dependency;
- excellent speak-anywhere dictation;
- local-first/offline core after model download;
- evidence-backed generated outputs;
- user-owned exportable source data;
- native Mac ergonomics and global shortcuts;
- optional local model choice without model-management clutter in the primary UI;
- robust recovery and no silent transcript/source loss.

Pocket / HeyPocket is a useful reference for reducing complexity in summary, task and Ask workflows. SuperDictate's product identity remains its own: native software capture, local-first processing, dictation-anywhere and explicit evidence/ownership.

## Design direction

The target design system is:

- Apple platform behavior first;
- system typography and semantic colors;
- OpenAI-inspired token architecture and restraint, not OpenAI branding;
- Pocket-like simplicity and single-purpose screens, not Pocket visual cloning;
- content before chrome;
- progressive disclosure for models, recovery, provenance and integrations;
- no dashboard-card default home;
- no permanent processing rail;
- no permanent inspector;
- no feature-inventory sidebar.

Primary Mac navigation target:

- Today
- Library
- Tasks
- Ask

Capture is a global action. Recording detail owns Summary / Transcript / Tasks. Models, storage, privacy and diagnostics belong in Settings.

## Quality bar

A release is not "done" because a demo flow works.

### Reliability

- completed transcript is never lost because insertion fails;
- kill/crash/interruption paths have explicit recovery fixtures;
- model corruption and interrupted download have deterministic recovery;
- hotkey behavior does not steal unrelated system/application shortcuts;
- no concurrent use of a shared neural graph when the engine cannot support it;
- installer/update rollback preserves the previous working app;
- migration from the existing v0.2.37 storage/settings identity is tested.

### Privacy

- short dictation works locally after model download;
- network use is explicit and inspectable;
- transcript contents never appear in diagnostics by default;
- cloud processing cannot silently become required for an existing local flow;
- delete/export semantics are clear per artifact type.

### UX

- one obvious primary action per primary screen;
- quick dictation requires no main-window interaction after setup;
- healthy technical states stay quiet;
- no user needs to understand "chunks", "manifests", model graph or updater internals to use the product;
- full keyboard navigation where macOS users expect it;
- native light/dark/increased-contrast behavior;
- Reduce Motion supported;
- every visible primary control works.

### Performance targets

Treat these as product targets to measure, not current claims:

- recording feedback should feel immediate after hotkey press;
- short dictation should return text quickly enough that the user does not prefer typing for short messages;
- UI interactions should remain smooth while local transcription runs;
- long recording capture must remain stable independently of AI processing speed;
- model cold-start cost should be visible only when unavoidable and progressively reduced through warmup/lifecycle strategy.

Maintain benchmarks per supported machine class before publishing performance claims.

## Phase 0 — Repository and baseline

Goal: create a trustworthy base before merging product experiments.

- finish PR #1 factual architecture/product baseline;
- inventory the existing stacked draft PRs;
- identify reusable commits/files rather than merging the full chain blindly;
- preserve `main` as current known-working behavior;
- make PR CI authoritative;
- add package/XCTest gates as code is extracted;
- keep all product work in feature branches/PRs.

Exit criteria:

- documented architecture and invariants;
- green current app CI;
- explicit decision for every open stacked PR: merge/rebase/cherry-pick/archive;
- no direct `main` work.

## Phase 1 — Independent distribution foundation

Goal: stop being operationally coupled to upstream without breaking updates.

- centralize source repository, release repository, update manifest, website/support and Homebrew routing;
- introduce typed distribution configuration rather than global string constants;
- document current bundle/settings/data identities;
- define future production identifiers and migration rules;
- create Direct vs App Store capability matrix;
- prepare Developer ID signing/notarization pipeline before switching public update URLs;
- keep existing safe routing until replacement artifacts actually exist.

Exit criteria:

- no scattered upstream identity constants;
- distribution configuration is testable;
- direct release pipeline can produce a verifiable artifact;
- identity migration plan is executable.

## Phase 2 — Extract the tested core

Goal: lower change cost without changing behavior.

PR-sized extractions:

1. shared domain/errors/config primitives;
2. transcript repair, corrections and filler processing;
3. hotkey transition state machine;
4. dictation lifecycle state machine;
5. settings/storage interfaces;
6. speech-engine protocol and FluidAudio adapter;
7. model manager boundaries;
8. insertion strategy boundary.

Rules:

- keep compatibility adapters in the executable;
- move tests with logic;
- no simultaneous visual redesign and low-level audio rewrite;
- preserve current self-tests as an integration gate.

Exit criteria:

- `main.swift` becomes application composition rather than the product implementation;
- pure logic has package tests;
- current dictation behavior remains regression-covered.

## Phase 3 — Native Design System v2

Goal: replace the workbench/dashboard direction with a calm Mac-native shell.

- machine-readable primitive/semantic/component tokens;
- SwiftUI semantic token adapter mapped to Apple system colors/fonts/materials;
- four-destination IA: Today / Library / Tasks / Ask;
- native toolbar and sidebar behavior;
- native Settings window;
- document-style Recording Detail;
- custom Recording HUD only where custom behavior is justified;
- progressive disclosure for recovery/provenance/model details;
- light/dark/increased-contrast/reduced-motion QA.

Exit criteria:

- default home has no metric-card dashboard;
- no permanent model picker, debug state, workflow strip or inspector;
- core tasks are usable by keyboard;
- design tokens, not ad hoc literals, own custom visual decisions.

## Phase 4 — Perfect Instant Dictation

Goal: make the invisible core better than competing "type with your voice" tools before expanding the review product.

### Capture

- faster/reliable first-start and model warmup;
- VAD and configurable auto-stop;
- pre-roll/post-roll so words at boundaries are not clipped;
- robust audio-route/device changes;
- clear but minimal recording/transcribing/error HUD;
- cancel without accidental insertion;
- deterministic busy behavior.

### Text

- Raw and Clean modes first;
- punctuation/paragraph cleanup;
- richer multilingual text repair;
- user dictionary and phrase corrections;
- snippets/expansions;
- per-app formatting profiles;
- optional local rewrite modes later: Message, Email, Prompt, Code, Translate, Custom.

### Insertion

- strategy abstraction per target app;
- direct insertion where reliable;
- clipboard fallback that never destroys the result;
- optional Enter behavior;
- app-specific compatibility registry learned from tests, not hard-coded UX guesses.

Exit criteria:

- short dictation is the product's strongest flow;
- no transcript loss in insertion failures;
- common target apps have automated/manual compatibility fixtures;
- latency and accuracy benchmarks exist by engine/machine/language.

## Phase 5 — Memory Capture vertical slice on macOS

Goal: deliver the Pocket-class conversation workflow in a SuperDictate-native way.

### Durable source

- long recordings written as crash-safe chunks/packages;
- recording title/time/duration/source context;
- pause/resume/marker;
- recovery/quarantine;
- source retention policy independent of processing.

### Recording detail

Three primary views:

1. Summary — readable structured note.
2. Transcript — speaker/timestamp-aware source text.
3. Tasks — checklist with evidence and execution status.

Additional contextual actions:

- Ask this recording;
- export/share;
- speaker/person correction;
- template/lens regenerate;
- technical details only when requested.

### Evidence

Generated decisions/tasks/claims retain source spans so the user can jump to the transcript/audio moment. Inferred data must remain distinguishable from stated data.

### Execution

- extracted tasks require user-verifiable evidence;
- stated owner/date is preserved;
- invented owner/date is prohibited;
- one-action calendar scheduling;
- unresolved tasks appear on Today/Tasks;
- source recording remains linked.

### Library

- native list and search;
- exact transcript search first;
- filters for date/people/tags/state;
- recycle bin/recovery;
- export/delete available without artificial premium lock-in.

Exit criteria:

- record -> process -> review -> schedule/export works end to end on Mac;
- recovery survives forced termination tests;
- every generated action can reveal its source;
- Today/Library remain visually light even with substantial history.

## Phase 6 — Ask and memory

Goal: make stored voice data useful without turning the product into generic chat.

Scopes:

- this recording;
- selected recordings;
- today/date range;
- person;
- project/tag;
- all local history.

Answer contract:

- concise answer first;
- evidence citations;
- explicit missing/uncertain evidence;
- no fabricated source;
- follow-up action only when it serves the recording/memory workflow.

Start with local indexing/search primitives where feasible; cloud/large-model enhancement remains optional and policy-gated.

## Phase 7 — Models without model UI clutter

Goal: support multiple engines while keeping defaults simple.

- recommended model per hardware/language;
- download/integrity/remove flows in Settings;
- Apple Silicon engine benchmarking (current FluidAudio/Parakeet plus justified alternatives such as WhisperKit only after test results);
- Intel `whisper.cpp` path only after maintained accuracy/RTF/memory benchmarks;
- local summarizer/LLM adapter behind explicit capability protocol;
- advanced model selection available in settings/regenerate flows, never required for basic recording.

Exit criteria:

- users can ignore model details entirely;
- experts can inspect/change them;
- published support matrix is backed by benchmarks.

## Phase 8 — Production distribution

### Direct edition

- Developer ID signing;
- notarization;
- reproducible release artifact;
- verified update manifest/channel;
- rollback;
- optional deeper integrations/CLI/MCP/Shortcuts where safe.

### Mac App Store edition

- sandbox target/config;
- capability-specific insertion fallback;
- App Store update path;
- review-compliant permissions/onboarding;
- TestFlight and migration validation.

Do not force identical capabilities where platform policy makes that unsafe or brittle.

## Phase 9 — Cross-device expansion

Only after the Mac vertical slice is excellent:

1. iPhone capture/library/review using shared domain contracts;
2. watchOS one-tap local-first capture and reliable handoff;
3. web only where it clearly improves library/admin/share workflows;
4. Android/Wear OS after product demand justifies parity work.

Existing exploratory branches for Apple shared core, chunking, local AI and cross-platform contracts should be mined for reusable code. They are research assets, not a mandate to ship every platform immediately.

## Git execution model

Do not recreate the current 19-PR dependency chain.

Preferred structure:

- merge a small stable foundation into `main`;
- start each next feature from current `main` unless a short explicit stack is unavoidable;
- keep stacks to a few PRs and collapse/rebase quickly;
- each PR has one behavioral responsibility;
- feature experiments can live in long-lived R&D branches but do not become the release spine.

Every PR must record:

- behavior change;
- tests/validation;
- privacy impact;
- migration impact;
- distribution/App Store impact;
- performance impact;
- rollback.

## Immediate next PR sequence

1. Complete and merge `audit/project-baseline`.
2. Reconcile/archive the old stacked PR chain while preserving useful commits.
3. `foundation/distribution-config` from the clean baseline.
4. `refactor/text-processing-core`.
5. `refactor/dictation-state-machine` and hotkey logic extraction.
6. `refactor/speech-engine-boundary`.
7. `design/native-tokens`.
8. `ui/native-shell-v2`.
9. `ui/recording-detail-v2`.
10. `feat/instant-dictation-quality` slices.
11. `feat/memory-capture-macos` slices.

The design-system work may be prototyped in parallel, but runtime merges should follow a clean, shallow dependency graph.
