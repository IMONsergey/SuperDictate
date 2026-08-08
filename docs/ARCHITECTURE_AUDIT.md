# SuperDictate architecture audit

Status: factual baseline for `main` at `ccec642b3eb7468ebce5adfb60e6779ee60b0258`.

Last reviewed: 2026-08-08.

## Executive verdict

SuperDictate is already a substantial local macOS dictation application, not a throwaway prototype. The current runtime contains working and defensive implementations for global shortcuts, audio capture, local ASR, transcript cleanup, corrections, history, diagnostics, permissions, recovery, updating and control-panel UI.

The main engineering problem is concentration: most runtime, UI, persistence, updater, permission, ASR and test logic lives in one very large `swift/Sources/Parakey/main.swift` executable target. That makes every product change expensive and increases regression risk.

The correct strategy is incremental extraction around tested behavior. Rewriting the audio/ASR path from scratch would discard working edge-case handling without solving the product problem.

## Current runtime

### Platform

- Swift 6.
- macOS 14 minimum.
- Apple Silicon only in the current public runtime and installer.
- AppKit / AVFoundation / CoreGraphics / ApplicationServices / CoreAudio / ServiceManagement.
- FluidAudio pinned by revision and Parakeet TDT v3 for local ASR.
- `LSUIElement` menu-bar/background-app behavior.

### User-facing capabilities already present

- global configurable dictation shortcut;
- toggle and hold trigger behavior;
- alternate completion shortcut;
- quick history shortcut;
- local microphone recording;
- local speech transcription;
- transcript insertion at the current target;
- optional Enter after insertion;
- recording/transcribing/error HUD;
- transcript history;
- local usage statistics;
- text corrections with import/export and sync-file support;
- filler-word cleanup;
- microphone input selection;
- RU/EN interface localization helpers;
- permissions/status control panel;
- update checking and in-app direct update flow;
- crash/interruption recovery paths;
- sanitized diagnostics.

## Strong engineering foundations to preserve

### Audio capture invariants

The current source explicitly documents and tests low-level behaviors that must survive extraction:

- `AudioCapture` must not be isolated to `MainActor`; the AVAudioEngine tap executes off the main actor and Swift 6 strict concurrency makes accidental actor isolation dangerous.
- a reused `AVAudioConverter` input provider must return `.noDataNow` after it supplies its current buffer; `.endOfStream` makes the converter terminal and can cause later recordings to capture silence.
- resource loading uses `Bundle.main` rather than SwiftPM `Bundle.module` because the generated resource bundle layout conflicts with the existing codesign packaging path.
- shared neural inference must not be allowed to overlap accidentally.

### Reliability and data integrity

The monolith contains more defensive behavior than the product surface suggests:

- pending dictation recovery;
- size and duration limits;
- model integrity verification and retry download;
- serial transcription worker with explicit reentrancy guard;
- safe correction-file handling with file-size limits and symlink rejection;
- correction sync fingerprints and three-way conflict handling;
- atomic local state writes in several critical paths;
- output-mute marker plus watchdog recovery;
- update checksum/version/bundle validation and rollback;
- bounded/sanitized diagnostics that avoid transcript contents.

These behaviors should become regression fixtures during extraction rather than being reimplemented from memory.

### Self-tests

The executable already carries a broad custom self-test suite that covers important pure behavior including:

- audio conversion and channel selection;
- HUD level normalization;
- transcript repair/corrections;
- correction transfer validation and merge behavior;
- configurable hotkey state transitions;
- toggle gating and cancellation behavior;
- update/version parsing and multiple reliability helpers.

The custom self-tests are useful, but long-term pure logic should move into Swift packages with XCTest while the executable-level self-test remains as an integration/regression gate.

## Current architecture constraints

### 1. Monolithic executable

`swift/Package.swift` currently exposes one executable product/target (`Parakey`). The main source file combines concerns that should have independent ownership:

- application lifecycle;
- settings;
- persistence;
- global hotkeys;
- audio capture;
- speech-engine lifecycle;
- text processing;
- insertion;
- permissions/TCC;
- model management;
- update checking/install;
- history/statistics;
- control-panel UI;
- HUD/history/statistics UI;
- diagnostics;
- self-tests.

This is the largest barrier to product velocity.

### 2. Distribution identity is still upstream-coupled

Current default installation/update paths still point at `shlgd/SuperDictate` in several places, including README/install/update constants. The fork cannot be considered an independent product until source identity, release identity and update channels are explicit and centralized.

Do not simply search-and-replace these URLs: the current fork does not yet have a complete signed/notarized release pipeline to replace upstream safely.

### 3. Technical product identity

The current bundle identifier and settings suite remain `com.local.superdictate`. Changing this can invalidate TCC grants or strand settings/history if done casually. A migration contract must precede any production identifier change.

### 4. One entitlement/distribution configuration

The current build uses one entitlement file and a shell-built app bundle. Direct Developer ID distribution and Mac App Store sandboxing have different capabilities and update rules, so they must become explicit editions/targets/configurations rather than scattered compile-time conditions.

### 5. UI is tightly coupled to runtime state

AppKit views and state transitions are embedded directly in the executable. This prevents the UI from being replaced safely and makes preview/mock state harder to test.

### 6. Storage is evolutionary rather than domain-driven

History/settings work today, but the future memory product needs explicit durable schemas for recordings, transcripts, generated outputs, evidence, people, tasks and deletion/recovery. These should not be added as more `UserDefaults` payloads inside the monolith.

## CI baseline

`.github/workflows/build.yml` currently runs on pull requests and `main` pushes with a macOS runner and performs:

1. `./scripts/check.sh`;
2. Swift executable self-tests;
3. app-bundle build;
4. codesign verification;
5. installer installation smoke;
6. installed-app verification;
7. uninstaller smoke.

This is a strong baseline. Future package tests, migration fixtures, edition builds and performance smoke tests should be additive.

## Product architecture target

### Layer A — SuperDictateCore

Pure/testable domain logic:

- dictation lifecycle/state machine;
- text repair and cleanup;
- corrections and snippets;
- recording/transcript/task/summary domain models;
- processing job state;
- evidence/provenance model;
- app/profile policy;
- capability/edition policy;
- migration versioning.

No AppKit, AVFoundation, filesystem, network or model-runtime ownership.

### Layer B — SuperDictateSpeech

Speech/model abstraction:

- `SpeechEngine` protocol;
- FluidAudio/Parakeet adapter;
- future WhisperKit/whisper.cpp adapters when benchmarks justify them;
- model catalog/install/integrity state;
- serialized inference policy;
- partial/final transcript interface.

### Layer C — SuperDictateAudio

Audio platform adapter:

- AVAudioEngine capture;
- input-device routing;
- sample normalization/conversion;
- VAD/pre-roll/post-roll later;
- crash-safe recording-package/chunk integration for long capture.

Keep realtime callbacks minimal and move heavy work off audio callbacks.

### Layer D — SuperDictateStore

Versioned storage and migrations:

- settings/preferences adapter;
- transcript history;
- long-form recording library;
- generated artifacts/evidence;
- tasks/people/tags;
- recovery/quarantine metadata;
- import/export.

### Layer E — SuperDictateAppKit / SuperDictateUI

Native product surface:

- macOS menu bar and global actions;
- lightweight SwiftUI/AppKit main window;
- recording HUD;
- onboarding/permissions;
- settings;
- Today / Library / Tasks / Ask;
- Recording Detail: Summary / Transcript / Tasks.

UI observes domain state and sends commands; it does not own ASR or persistence logic.

### Layer F — Distribution adapters

Direct edition:

- Developer ID;
- notarization;
- updater;
- deeper system integrations;
- optional CLI/MCP/Shortcuts helpers where permitted.

Mac App Store edition:

- sandboxed capabilities;
- App Store updates;
- safe clipboard fallback when direct insertion or helper behavior is incompatible with sandbox/review requirements.

## Migration rules

- Never change bundle identifiers, settings suite, app-support paths, model paths or launch-agent identity without a tested migration.
- Never delete a transcript because insertion failed.
- Never delete source audio because downstream processing/upload completed unless explicit retention policy permits it.
- Existing v0.2.37 installations are fixtures for migration testing.
- Any storage format introduced for the memory product must be versioned from its first release.

## Recommended execution order

1. Finish this factual baseline and merge it independently.
2. Centralize distribution/source/release configuration without changing working release routing yet.
3. Extract pure core/text/hotkey state with tests.
4. Introduce speech-engine and storage boundaries.
5. Replace UI through a native design-system layer while preserving current dictation behavior.
6. Perfect short dictation before adding long-form memory complexity to the default flow.
7. Add long-form recording/memory as a second product surface sharing the core.
8. Separate Direct and App Store editions.
9. Only after the Mac vertical slice is reliable, revive the already-explored iOS/watchOS/cross-platform work in controlled PRs.

## Do not do

- do not rewrite the audio engine merely for architectural cleanliness;
- do not merge the current long stacked PR chain blindly;
- do not make a browser workbench the primary product architecture;
- do not expose model/runtime/debug state as default UI;
- do not promise Intel parity until a real local-engine benchmark is maintained in CI/device testing;
- do not make cloud processing a hidden dependency for basic dictation;
- do not turn SuperDictate into a generic AI dashboard.
