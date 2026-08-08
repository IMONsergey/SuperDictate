# SuperDictate legacy R&D stack reconciliation

Status: execution decision record.

Last reviewed: 2026-08-08.

## Why this document exists

The repository accumulated a long chain of stacked draft PRs while exploring cross-platform recording, local-first sync, intelligence, SwiftUI workbench concepts, Intel support and Pocket-like product surfaces.

That work contains useful research and code, but the dependency chain is too deep to become the production release spine safely. The production path now starts from the verified macOS baseline on `main` and ports useful ideas in small focused PRs.

Closing a legacy draft after this reconciliation does **not** mean deleting its branch or rejecting every idea inside it. It means the branch is a research source rather than a merge target.

## Decision vocabulary

- **Mine later** — keep branch/PR as source material; port selected code/ideas into a new PR from current `main`.
- **Superseded** — production replacement now exists or is being built; do not merge the old PR.
- **Archive research** — useful conceptual reference but not on current delivery path.
- **Re-evaluate** — decision depends on benchmarks/platform demand not yet available.

## PR-by-PR decisions

### PR #2 — Define cross-platform SuperDictate foundation

Decision: **Archive research / mine later**.

Keep:

- native-client principle;
- versioned service/domain contract ideas;
- local-first capture requirement;
- resumable upload/idempotency principles.

Do not merge now:

- broad iOS/watchOS/Android/web delivery sequence;
- backend commitment before the Mac vertical slice is excellent.

Production destination:

- Mac first;
- shared contracts only when a second real client needs them.

### PR #3 — Add shared Apple recording core

Decision: **Mine later**.

Keep:

- deterministic lifecycle/state-machine thinking;
- platform-independent recording concepts;
- retry/state tests.

Do not merge as a stacked dependency. Port the smallest useful state machines into the current `SuperDictateCore` only when the runtime adapter is ready.

### PR #4 — Define intelligence, memory, trust and wearable product semantics

Decision: **Archive research / mine later**.

High-value material:

- evidence-backed outputs;
- stated vs inferred information;
- memory candidate trust;
- task provenance;
- no invented owner/deadline;
- clear cloud/retention policy.

Low current priority:

- wearable-specific product semantics before Mac Memory Capture.

### PR #5 — Add local-first recording and durable synchronization core

Decision: **Mine later for Memory Capture**.

Keep:

- stable recording/chunk identities;
- acknowledgement monotonicity;
- idempotent upload/retry behavior;
- source deletion independent from transfer success;
- quota never blocking local capture.

Do not merge before we actually need cross-device/cloud transfer.

### PR #6 — Persist Apple recording manifests and upload queue atomically

Decision: **Mine later**.

Keep atomic persistence ideas and tests. Reintroduce only behind the final macOS recording package schema instead of making the old cross-platform manifest the new source of truth by default.

### PR #7 — Add Codex continuation handoff

Decision: **Superseded**.

Reason: current `PROJECT_STATE.md`, `ARCHITECTURE_AUDIT.md`, `PRODUCT_ROADMAP_V2.md`, `DESIGN_SYSTEM_V2.md` and this reconciliation document are now the current source of truth.

The old handoff remains useful historical context but should not drive new execution.

### PR #8 — Add crash-safe Apple chunk writer

Decision: **High-value mine later for Phase 5**.

Keep:

- write/flush/close/checksum/manifest ordering;
- recovery journal;
- quarantine instead of silent deletion;
- fault-injection tests;
- immutable closed chunks.

This is one of the most valuable R&D branches, but it should be ported only after the production recording package schema is defined from current `main`.

### PR #9 — Add Apple audio capture adapter boundary

Decision: **Mine later**.

Keep separation between deterministic capture lifecycle and AVFoundation execution. Reuse after Instant Dictation core extraction and before long-form Memory Capture capture replacement.

### PR #10 — Add AVFoundation chunk engine

Decision: **Mine later**.

Keep CAF encoding/chunk persistence approach if benchmarks and device tests still support it. Do not replace the current short-dictation `AudioCapture` path merely because this branch exists.

### PR #11 — Add local AI processing foundation

Decision: **Mine later**.

Keep:

- capability-based local model adapters;
- partial-success processing semantics;
- transcript/summary/action separation;
- rule-based fallback concepts where useful.

Do not bring the old model catalog/workbench abstractions wholesale into the new simple product UI.

### PR #12 — Add native processing workbench state

Decision: **Superseded**.

Reason: the new production `SuperDictateCore` intentionally exposes a much smaller product state. The old workbench model leaked implementation concepts into primary presentation.

Mine only any isolated validation helper that still proves useful.

### PR #13 — Add SwiftUI workbench package

Decision: **Superseded**.

Reason: the three-column/feature-panel workbench UI conflicts with Design System v2. Production replacement is `SuperDictateUI` on the clean spine.

### PR #14 — Open SwiftUI workbench from macOS app

Decision: **Superseded, integration idea retained**.

Keep the lesson that SwiftUI should be wired to live runtime state. Do not reuse the old workbench UI or its direct integration shape blindly.

The new integration uses the existing two-process architecture: background agent as engine, control-panel process as native product UI.

### PR #15 — Add Intel whisper preview workbench

Decision: **Re-evaluate**.

Keep:

- Intel `whisper.cpp` exploration;
- model setup/testing notes;
- any reproducible benchmark harness.

Do not promise Intel production support until current engine accuracy, real-time factor, memory use, packaging and maintenance cost are measured on supported Intel hardware.

The web workbench inside this PR is not production UI.

### PR #16 — Document native design reference system

Decision: **Superseded by Design System v2**.

Any still-useful Apple/open-source references can be copied into current design research when needed. The normative contract is now `docs/DESIGN_SYSTEM_V2.md`.

### PR #17 — Redesign web workbench interface

Decision: **Superseded**.

Keep only behavior prototypes if they help test a future flow. Do not use the visual composition as a native Mac target.

### PR #18 — Document Pocket alternative product mechanics

Decision: **Superseded by current Pocket reference**.

The new `POCKET_PRODUCT_REFERENCE_V2.md` is based on a later source review and aligns directly with the production Mac-first architecture.

### PR #19 — Redesign web workbench as Pocket-style console

Decision: **Superseded as UI; retain behavior experiment**.

Useful:

- quick experimentation with Ask/task/calendar/memory mechanics.

Do not merge:

- dense navigation;
- workflow strip;
- three-column chrome;
- permanent model/runtime/recovery UI;
- dashboard/card-heavy visual language.

### PR #20 — Define lightweight native design system v2 (old stacked design branch)

Decision: **Superseded by clean production design-system PR**.

Reason: its design conclusions are now being rebuilt directly from `main` in the production product-spine branch instead of remaining dependent on the Pocket R&D stack.

### PR #21 — Rebuild native shell around lightweight design system (old stacked UI branch)

Decision: **Superseded by clean `SuperDictateUI` implementation**.

The clean production version keeps the same central insight but removes the old stacked dependencies.

## Production code we should actively mine later

Highest-value legacy engineering assets, in approximate order:

1. PR #8 crash-safe chunk writer + recovery fault tests.
2. PR #9/#10 deterministic capture adapter + AVFoundation chunk engine.
3. PR #4 evidence/trust semantics.
4. PR #11 processing capability/partial-success patterns.
5. PR #5/#6 idempotent sync + atomic persistence when sync becomes real.
6. PR #3 pure recording lifecycle ideas.
7. PR #15 Intel benchmark/setup work if Intel becomes a production target.

## Production ideas we should not resurrect

- broad cross-platform scope before Mac excellence;
- 8–12 destination sidebars;
- permanent model management in primary chrome;
- pipeline dashboards;
- permanent inspectors;
- a separate global AI Review destination;
- web preview UI as a native design source;
- backend/sync architecture before the local Mac source schema is stable;
- fake product parity driven by roadmap completeness rather than user value.

## Safe cleanup plan

After the clean product-spine and native-window integration are merged and green:

1. add a short superseded/archived comment to old draft PRs;
2. close PR #2–#21 that are not active merge targets;
3. keep branches available as research history;
4. link this document from `PROJECT_STATE.md`;
5. port reusable code only through new focused PRs from current `main`;
6. never reopen the old dependency chain by making new production branches depend on it.

## Current release spine

Target shallow sequence:

```text
main
  -> clean product spine / design system
  -> trusted runtime bridge
  -> native main-window integration
  -> distribution config
  -> deterministic core extraction
  -> Instant Dictation quality slices
  -> macOS Memory Capture slices
```

Short temporary stacks are acceptable, but they should collapse into `main` quickly.

## Rule for mining an old PR

Before copying code from an R&D branch, answer:

1. What exact invariant or capability are we preserving?
2. Is the old abstraction still correct for the current Mac-first product?
3. Can we port a smaller piece instead of the whole dependency chain?
4. Which current regression tests protect the port?
5. Does this introduce any migration/privacy/distribution change?
6. Can we delete/revert the port independently if it is wrong?

If those questions cannot be answered, keep the old code as research and do not merge it.
