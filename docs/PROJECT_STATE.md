# SuperDictate project state

_Last updated: 2026-08-08_

## Repository baseline

- Repository: `IMONsergey/SuperDictate`
- Baseline branch: `main`
- Baseline commit: `ccec642b3eb7468ebce5adfb60e6779ee60b0258`
- Baseline release: `v0.2.37`
- Upstream origin: `shlgd/SuperDictate`
- License: MIT; `LICENSE` and `NOTICE.md` must remain intact.

Supporting baseline documents:

- `docs/ARCHITECTURE_AUDIT.md` — factual runtime/build/reliability audit.
- `docs/PRODUCT_ROADMAP_V2.md` — product and implementation roadmap after repository review.

## Product direction

SuperDictate is being developed into an independent, polished, local-first macOS voice product rather than a lightly renamed copy of the upstream utility.

The product has two deliberately separate user-facing jobs:

1. **Instant Dictation** — global-hotkey speech-to-text and insertion with almost no interface.
2. **Memory Capture** — long-form conversations/thoughts that become a recording detail with Summary, Transcript, Tasks and scoped Ask.

They share audio, speech engines, corrections, language/model policy, storage and search. They must not share all UI; instant dictation remains nearly invisible while memory/review uses a lightweight native window.

Basic dictation must remain useful without an account or cloud transcription service. Audio and normal dictation processing stay on the Mac by default after model download. Optional network/cloud/AI capabilities must be explicit, inspectable and separately enabled.

Two macOS editions remain planned from shared code:

1. **Direct edition** — Developer ID distribution, notarization, updater and deeper system integrations.
2. **Mac App Store edition** — App Sandbox/App Store update path with capability-specific fallbacks where sandbox/review rules require them.

## Design direction

A separate design-system workstream now defines the target interface:

- native Apple behavior first;
- system typography, semantic colors, native controls and keyboard conventions;
- OpenAI-inspired token architecture and visual restraint without copying OpenAI branding;
- Pocket / HeyPocket as a reference for low interface complexity and single-purpose screens, not as a brand/visual clone;
- content before chrome;
- progressive disclosure for models, recovery, provenance and integrations.

Target primary Mac navigation:

- Today
- Library
- Tasks
- Ask

Capture is a global action rather than a navigation destination. Summary / Transcript / Tasks belong to a Recording Detail. Models/storage/privacy/diagnostics belong in Settings. Permanent workflow strips, metric dashboards, model selectors and inspectors are rejected from default primary chrome.

The design-system prototype is tracked independently so it does not block factual baseline work.

## Current technical baseline

The application currently uses Swift 6, AppKit, AVFoundation, CoreGraphics and FluidAudio/Parakeet on Apple Silicon. It provides global hotkeys, local speech recognition, transcript history, corrections, filler-word removal, a recording HUD, an updater, install scripts and a background agent.

The main technical constraint is the large `swift/Sources/Parakey/main.swift` monolith, which currently combines application lifecycle, UI, audio capture, ASR, text processing, settings, persistence, permissions, diagnostics, updater and tests.

Important low-level invariants must be preserved during refactoring:

- `AudioCapture` must not be isolated to `MainActor`.
- Reused `AVAudioConverter` input providers must return `.noDataNow`, not `.endOfStream`, after supplying the current buffer.
- Shared neural/CoreML inference must not run concurrently unless the chosen engine explicitly supports it.
- Existing bundle identifiers, data paths, history, settings, downloaded models and permissions must not be changed without a tested migration.
- Failed insertion must never destroy the transcript.
- Diagnostics must not include transcript text, correction contents, secrets or full private paths.

The current runtime also contains meaningful defensive engineering that must be preserved during extraction: pending dictation recovery, correction-file safety/conflict handling, model integrity verification, update validation/rollback, system-audio mute recovery, bounded diagnostics and broad executable self-tests.

## CI baseline

The current `main` workflow performs:

1. repository script/plist validation;
2. Swift executable self-tests;
3. app-bundle build;
4. codesign verification;
5. installer smoke test;
6. installed-app verification;
7. uninstaller smoke test.

Future package tests, migrations, edition builds and performance checks should extend this baseline instead of replacing it.

## Delivery rules

- Never edit `main` directly.
- Each change is developed in a focused feature branch and reviewed through a pull request.
- Every PR must describe behavior, tests, privacy impact, App Store/distribution impact, migration impact, performance impact and rollback considerations.
- Working low-level audio and ASR code is not rewritten without regression tests.
- Large formatting-only changes must not be mixed with functional work.
- Product identity, distribution routing and edition capabilities must be centralized rather than scattered through conditional compilation.
- Avoid long PR dependency chains; merge small stable foundations quickly and start subsequent work from current `main` whenever possible.

## Existing stacked R&D branches

The repository currently contains a long chain of open draft PRs exploring cross-platform product semantics, shared Apple core, durable recording packages/chunks, local AI processing, SwiftUI workbench UI, Intel whisper preview, Pocket research and web interfaces.

These branches contain useful research and reusable code, but the chain must not be merged blindly. The immediate repository-management task after this baseline is to classify each stack segment as:

- merge/rebase as a small stable foundation;
- cherry-pick/reimplement selected reusable files;
- keep as R&D reference;
- archive/close when superseded.

Mac product quality remains the release spine. iOS/watchOS/Android/web expansion follows after the Mac vertical slice is reliable and coherent.

## Planned delivery sequence

1. `audit/project-baseline` — factual repository audit and product roadmap.
2. reconcile the existing stacked draft PR chain.
3. `foundation/distribution-config` — independent source/release/update configuration without prematurely breaking current routing.
4. `refactor/text-processing-core` — corrections, repair and filler processing with package tests.
5. `refactor/dictation-state-machine` — deterministic dictation/hotkey lifecycle extraction.
6. `refactor/speech-engine-boundary` — engine abstraction, current FluidAudio adapter and model manager boundary.
7. `refactor/storage-boundary` — versioned settings/history/library interfaces and migrations.
8. `design/native-tokens` — semantic token adapters and accessibility policy.
9. `ui/native-shell-v2` — calm Today / Library / Tasks / Ask shell.
10. `ui/recording-detail-v2` — document-style Summary / Transcript / Tasks.
11. focused Instant Dictation quality PRs — latency/warmup, VAD/pre-roll/post-roll, text modes, dictionary/snippets, app profiles and insertion strategies.
12. focused macOS Memory Capture PRs — durable long recording, evidence, tasks/calendar, library/search, Ask.
13. Direct Developer ID/notarized distribution.
14. Mac App Store target/sandbox/TestFlight.
15. controlled iOS/watchOS expansion; Android/web only when justified by product demand.

See `docs/PRODUCT_ROADMAP_V2.md` for detailed phases and exit criteria.

## Current phase

**Phase 0: repository baseline and stack cleanup.**

The factual code/build audit is now recorded. The next engineering step is not another broad feature branch: it is to get this baseline green, merge it, reconcile the existing draft stack, then start the first independent distribution/core extraction PRs from a clean base.

Design prototyping can continue in parallel because it is documentation/token/UI work and does not require rewriting the current audio/ASR runtime.

## Known risks

- The fork still depends on upstream release infrastructure in several places; switching those URLs before replacement artifacts exist would break installation/update behavior.
- The public build is not yet distributed through a complete Developer ID/notarization pipeline.
- Changing `com.local.superdictate`, settings suites, app-support paths or launch-agent identity without migration can strand user data/permissions.
- App Store sandboxing may require a different insertion strategy from the Direct edition.
- Intel support requires maintained engine/performance/accuracy testing and must not be promised from an exploratory preview alone.
- Refactoring the monolith without incremental compatibility adapters would create high regression risk.
- The current long stacked PR chain makes review, CI interpretation and future rebasing unnecessarily expensive.
- The current workbench/web experiments expose too much technical/product surface and must not define the final native IA.

## Next concrete action

1. Validate this documentation-only baseline PR and merge it when CI is green.
2. Reconcile the existing PR stack into a shallow delivery graph.
3. Start `foundation/distribution-config` from the resulting clean `main`.
4. In parallel, continue the lightweight native design-system prototype without merging the previous dashboard/workbench UI as the product target.
