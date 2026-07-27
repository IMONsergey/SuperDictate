# SuperDictate project state

_Last updated: 2026-07-27_

## Repository baseline

- Repository: `IMONsergey/SuperDictate`
- Baseline branch: `main`
- Baseline commit: `ccec642b3eb7468ebce5adfb60e6779ee60b0258`
- Baseline release: `v0.2.37`
- Upstream origin: `shlgd/SuperDictate`
- License: MIT; `LICENSE` and `NOTICE.md` must remain intact.

## Product direction

The fork is being developed into an independent, polished, local-first macOS dictation product rather than a lightly renamed copy of the upstream utility.

The product must remain useful without an account or cloud transcription service. Audio and normal dictation processing stay on the Mac by default. Optional network or AI features must be explicit, inspectable, and separately enabled.

Two editions are planned from one shared codebase:

1. **Direct edition** — Developer ID distribution, notarization, automatic insertion, updater, CLI/MCP and deeper system integrations.
2. **Mac App Store edition** — App Sandbox, App Store updates, reduced capabilities where sandbox or review rules require it, and a reliable copy-to-clipboard fallback.

## Current technical baseline

The application currently uses Swift 6, AppKit, AVFoundation, CoreGraphics and FluidAudio/Parakeet on Apple Silicon. It provides global hotkeys, local speech recognition, transcript history, corrections, filler-word removal, a recording HUD, an updater, install scripts and a background agent.

The main technical constraint is the large `swift/Sources/Parakey/main.swift` monolith, which currently combines application lifecycle, UI, audio capture, ASR, text processing, settings, persistence, permissions, diagnostics, updater and tests.

Important low-level invariants must be preserved during refactoring:

- `AudioCapture` must not be isolated to `MainActor`.
- Reused `AVAudioConverter` input providers must return `.noDataNow`, not `.endOfStream`, after supplying the current buffer.
- CoreML inference on a shared graph must not run concurrently.
- Existing bundle identifiers, data paths, history, settings, downloaded models and permissions must not be changed without a tested migration.
- Failed insertion must never destroy the transcript.
- Diagnostics must not include transcript text, correction contents, secrets or full private paths.

## Delivery rules

- Never edit `main` directly.
- Each change is developed in a focused feature branch and reviewed through a pull request.
- Every PR must describe behavior, tests, privacy impact, App Store impact, migration impact, performance impact and rollback considerations.
- Working low-level audio and ASR code is not rewritten without regression tests.
- Large formatting-only changes must not be mixed with functional work.
- Product identity, distribution routing and edition capabilities must be centralized rather than scattered through conditional compilation.

## Planned delivery sequence

1. `audit/project-baseline` — factual repository audit, product/architecture documents and baseline verification.
2. `foundation/distribution-config` — independent source identity and explicit separation of source, binary release and update channels.
3. `refactor/core-foundation` — extract pure logic into a testable `SuperDictateCore` module.
4. `refactor/text-processing-core` — corrections, model text repair and filler-word processing with regression tests.
5. `refactor/dictation-state-machine` — deterministic lifecycle independent of AppKit.
6. `refactor/speech-engine-protocol` — engine abstraction, FluidAudio adapter and model manager.
7. `build/product-editions` — Direct and App Store targets with a capability matrix.
8. `ui/design-system` — semantic visual tokens, accessibility and motion policy.
9. `ui/recorder-hud` — redesigned recording/transcription/completion/error experience.
10. `ui/onboarding-permissions` — contextual permission flow, model setup and first dictation.
11. `feat/history-storage` — searchable SQLite history and migrations.
12. `feat/dictionary-snippets` — scoped corrections, snippets and import/export.
13. `feat/streaming-vad` — streaming transcript, VAD, auto-stop, pre-roll and post-roll.
14. `feat/processing-modes` — Raw, Clean, Message, Email, Prompt, Code, Translate and Custom modes.
15. `feat/app-profiles` — application-aware defaults and safe insertion strategies.
16. `feat/direct-agent-tools` — Direct-only MCP, CLI, Shortcuts and URL scheme.
17. `release/direct-notarized` — reproducible signed and notarized direct releases.
18. `release/app-store` — sandbox validation, TestFlight, metadata and submission package.

## Current phase

**Phase 0: repository baseline and operating model.**

This branch establishes the persistent project state document and confirms that the connected GitHub workflow can create branches and commits directly. The next changes in this branch should add a factual architecture map, baseline command results, product vision, App Store strategy and UX/motion principles based on the actual repository contents.

## Known risks

- The fork currently depends on upstream release infrastructure in several places; switching those URLs prematurely would break installation and updates.
- The public build is not yet distributed through a complete Developer ID/notarization pipeline.
- App Store sandboxing may require a different insertion strategy from the Direct edition.
- Intel support requires a separate engine evaluation and must not be promised before performance and licensing are validated.
- Refactoring the monolith without incremental compatibility adapters would create a high regression risk.

## Next concrete action

Complete the factual audit on `audit/project-baseline`, run all available baseline checks, add the supporting documents, and open the first pull request without changing runtime behavior.