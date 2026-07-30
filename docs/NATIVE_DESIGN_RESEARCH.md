# Native Design Research For SuperDictate

Status: working research brief.

Last verified: 2026-07-30.

Goal: define the design references, rules, and immediate product decisions for a
beautiful, native-feeling, local-first SuperDictate experience on macOS first,
then iOS, watchOS, and a web preview.

## Executive Decision

The SuperDictate UI should be a native Mac recording and transcript workbench.
It should not be a dashboard, a raw developer console, a marketing page, or a
copy of another dictation app.

The strongest direction is:

- Apple HIG and Apple Design Resources define the platform contract.
- CodeEdit defines the high-quality Mac workbench bar.
- CotEditor defines restraint, text quality, and familiar Mac behavior.
- NetNewsWire defines long-session reading comfort and sidebar hierarchy.
- IceCubes defines multiplatform SwiftUI adaptation and live/cached state.
- Pindrop defines the dictation domain, model browser, hotkeys, local-first
  posture, and first-run model setup.
- Argmax OSS Swift defines the Apple Silicon on-device speech AI direction.
- KeyboardShortcuts and Sparkle define production-grade Mac utility details.
- Fluent UI Apple is useful only for token architecture, not visual style.

## Evaluation Criteria

Every reference below was judged against these SuperDictate needs:

- Native macOS feel.
- Clear primary workflow.
- Local-first trust.
- Model visibility and model management.
- Transcript editing and reading quality.
- Fast capture from anywhere.
- Recovery and data integrity that nontechnical users can understand.
- Multiplatform path without weakening the Mac app.
- Open-source practicality.

## Primary Apple Sources

### Apple Human Interface Guidelines

Source: https://developer.apple.com/design/human-interface-guidelines/

Use as the top-level standard for platform feel: design principles, macOS and
iOS foundations, patterns, components, inputs, accessibility, color, typography,
layout, materials, and app icons.

SuperDictate decision:

- Use native window, toolbar, sidebar, inspector, settings, menu, command, and
  keyboard patterns first.
- Treat HIG mismatches as defects, not taste.
- Use web preview only as a reviewable prototype surface.

### Apple Design Resources

Source: https://developer.apple.com/design/resources/

Apple provides official templates, icon production templates, color guides, UI
kits for iOS/iPadOS and macOS, fonts, SF Symbols, and Icon Composer.

SuperDictate decision:

- Use the Apple macOS and iOS UI kits as the visual measurement baseline.
- Use SF Pro/Text and SF Symbols by default.
- Use SF Mono only for code-like metadata: timestamps, checksums, logs, model
  identifiers, and recovery journal details.
- Use Icon Composer later for a layered Mac/iOS app icon instead of an improvised
  generated logo.

### Apple Style Guide

Source: https://help.apple.com/applestyleguide/

Use for product copy, labels, menu names, settings wording, and help text.

SuperDictate decision:

- Prefer direct user-facing nouns: Recording, Transcript, Summary, Tasks,
  Export, Model, Recovery.
- Move implementation words like `manifest`, `checksum`, `chunk`, `journal`,
  and `sha256` into technical details unless the user explicitly opens them.

## Product References

### CodeEdit

Sources:

- https://github.com/CodeEditApp/CodeEdit
- https://www.codeedit.app/blog/2024/01/why-were-building-codeedit
- https://www.codeedit.app/blog/2025/07/new-packages-announcement

Why it matters:

CodeEdit is a serious Swift-native macOS workbench project. Its public writing
frames native Mac performance, HIG alignment, familiar interaction, welcome
windows, and thoughtful utility-window polish as first-order product goals.

Borrow:

- Mac workbench composition: sidebar, toolbar, detail area, inspectors,
  preferences, commands.
- Welcome window thinking for first launch and recent recordings.
- About window and update/delight moments that remain utilitarian.
- Native SwiftUI package boundaries for reusable windows.

Avoid:

- Code-editor information architecture.
- Overfitting SuperDictate to project/file concepts.

SuperDictate decision:

Use CodeEdit as the bar for "this feels like a Mac app with serious intent."
The SuperDictate equivalent is a transcript workbench with fast capture and
clear local AI status.

### CotEditor

Source: https://github.com/coteditor/CotEditor

Why it matters:

CotEditor is an established native macOS editor with a clear philosophy:
first-class Mac behavior, native controls, accessibility, localization, and
less complexity.

Borrow:

- Text editing quality and keyboard behavior.
- Native control restraint.
- Beginner-friendly surface with advanced precision available.
- Localization and accessibility seriousness.

Avoid:

- Plain-editor minimalism that hides SuperDictate's recording, AI, and model
  states.

SuperDictate decision:

Transcript reading/editing must feel closer to a native editor than to a web
textarea. The product should be calm even when it exposes advanced recovery or
model details.

### NetNewsWire

Sources:

- https://github.com/Ranchero-Software/NetNewsWire
- https://netnewswire.com/

Why it matters:

NetNewsWire is a mature Mac/iOS open-source app with comfortable reading
hierarchy, sidebar organization, keyboard navigation, multi-window behavior, and
quiet reliability.

Borrow:

- Sidebar hierarchy.
- Reading pane comfort.
- Search, smart groups, empty states, and multi-window Mac expectations.
- Keyboard navigation for long sessions.

Avoid:

- Feed-reader mental model.

SuperDictate decision:

Recordings and transcripts should be browsable like a library, but active
recording remains the primary mode.

### IceCubesApp

Source: https://github.com/Dimillian/IceCubesApp

Why it matters:

IceCubes is a full SwiftUI app across iOS, macOS, iPadOS, and visionOS with a
dedicated sidebar UI on larger platforms, live updates, cached state, drafts,
and AI-assisted text tools.

Borrow:

- Multiplatform SwiftUI navigation strategy.
- Dedicated Mac/iPad sidebars instead of lowest-common-denominator layouts.
- Draft-like persistence for unfinished recordings, notes, summaries, and
  exports.
- Live update patterns.

Avoid:

- Social-client density and feed pressure.

SuperDictate decision:

Design one product system with platform-specific layouts. Mac gets the full
workbench; iPhone gets capture/review; watch gets quick capture; web remains a
preview and compatibility surface.

### Pindrop

Source: https://github.com/watzon/pindrop

Why it matters:

Pindrop is the closest current open-source product reference: a Mac-native
dictation app with local transcription engines, a model browser, global hotkeys,
history, export, custom dictionary, optional AI enhancement, and offline speaker
diarization.

Borrow:

- First-run flow: microphone permission, model download, hotkey setup.
- Model browser that recommends options for the current Mac.
- Local-first trust copy and visible privacy state.
- Toggle and push-to-talk recording modes.
- Transcript history with search, editing, playback, and exports.
- Custom dictionary and vocabulary bias.
- Optional AI cleanup that is off by default.

Avoid:

- Menu-bar-only scope as the main experience.
- Apple-Silicon-only assumptions for Intel testing.
- Copying visual identity or product positioning.

SuperDictate decision:

Pindrop proves the expected feature set for a serious dictation utility. We need
the same clarity but a broader workbench for meetings, summaries, tasks,
recovery, and evidence.

## Technology References

### Argmax OSS Swift

Source: https://github.com/argmaxinc/argmax-oss-swift

Why it matters:

Argmax packages WhisperKit, SpeakerKit, and TTSKit as on-device speech AI for
Apple platforms. The open-source SDK is the right long-term native AI direction
for Apple Silicon.

SuperDictate decision:

- Use `whisper.cpp` as the pragmatic Intel test path.
- Keep the model manager abstract enough to add WhisperKit on Apple Silicon.
- Treat diarization and TTS as roadmap modules, not as UI afterthoughts.

### KeyboardShortcuts

Source: https://github.com/sindresorhus/KeyboardShortcuts

Why it matters:

It provides user-customizable global shortcuts, a native recorder UI, system
conflict warnings, sandbox compatibility, and SwiftUI/AppKit support.

SuperDictate decision:

Use a native shortcut recorder for toggle recording, push-to-talk, cancel,
marker, and quick paste/export actions.

### Sparkle

Source: https://github.com/sparkle-project/Sparkle

Why it matters:

Sparkle is the mature Mac update framework: secure verification, sandbox
support, delta updates, channels, phased rollouts, and custom UI support.

SuperDictate decision:

Add Sparkle after the local build becomes useful enough for repeated testing.
The update UI should be quiet and trust-building, not a marketing surface.

### Fluent UI Apple Tokens

Source: https://github.com/microsoft/fluentui-apple/wiki/Design-Tokens

Why it matters:

The useful part is the token hierarchy: raw global values, semantic alias
tokens, and component/control tokens.

SuperDictate decision:

Build our own native token layer:

- Global: spacing, radius, font sizes, raw semantic colors.
- Alias: background, surface, separator, primary action, verified, warning,
  destructive, transcript text, metadata text.
- Control: recorder button, model badge, timeline segment, task chip, export
  button, inspector row, recovery state.

Do not copy Fluent's product look.

## SuperDictate Native Workbench Model

### First Launch

The first-run flow should be a native welcome window:

1. Grant microphone permission.
2. Pick a recommended local model for this Mac.
3. Download or locate the model.
4. Set optional hotkeys.
5. Choose clipboard/direct insertion/export behavior.
6. Start a test recording.

### Main macOS Window

Use a three-area workbench:

- Sidebar:
  Recordings, Today, Transcript Library, Tasks, Models, Recovery, Settings.
- Center:
  current recording, waveform/timeline, live transcript, editor, summary,
  decisions, risks, tasks, and exports.
- Inspector:
  active model, runtime, language, storage path, chunk health, recovery state,
  provenance, privacy mode, and technical details disclosure.

Toolbar controls:

- Record
- Pause
- Stop
- Marker
- Model selector
- Search
- Export

The current model and privacy state should be visible even while the sidebar is
collapsed.

### Menu Bar Surface

The menu bar surface is for fast capture:

- Start/stop recording.
- Toggle push-to-talk state.
- Show current model and local/offline state.
- Copy last transcript.
- Open the workbench.

It is not the whole product.

### Transcript And AI Review

Transcript view:

- Live text with timestamps and speaker lanes.
- Editable transcript after finalization.
- Playback-linked segments.
- Search and replace.
- Custom dictionary suggestions.

AI review:

- Summary.
- Decisions.
- Action items.
- Risks.
- Follow-up questions.
- Memories/candidate facts only with provenance.

Generated text must stay visually distinct from source transcript.

### Model Manager

Each model row/card needs:

- Recommended badge for this Mac.
- Installed/download required state.
- Engine: whisper.cpp, WhisperKit, Apple speech stack, Parakeet, or future
  local model.
- Size on disk.
- Expected speed class.
- Accuracy class.
- Language coverage.
- Privacy mode.
- Source/license.
- Actions: download, use, remove, reveal in Finder, verify.

Default for Intel testing:

- `whisper.cpp` with Whisper Base, because it is small enough for quick testing
  and good enough to validate the product loop.

Later choices:

- Tiny for fastest short dictation.
- Small/Medium for higher accuracy.
- WhisperKit/Core ML variants for Apple Silicon.
- Optional summarizer through a local Ollama/LM Studio adapter after transcript
  quality is stable.

### Recovery Center

The recovery center should speak human language first:

- Recording safely saved.
- Recording paused.
- Finalizing transcript.
- 2 chunks verified.
- Recovery available.
- Needs review.
- Technical details.

Technical detail disclosure can show:

- chunk identifiers
- checksums
- manifest path
- recovery journal entries
- retry and crash simulation evidence

## Visual Direction

The app should be quiet, native, and distinctive through craft instead of loud
decoration.

Use:

- system backgrounds and materials
- native sidebars and inspectors
- precise typography
- simple status color
- SF Symbols
- real waveform/timeline visualization
- compact tables where scanning matters
- readable transcript panes

Avoid:

- large decorative cards
- one-color palettes
- raw JSON panels as first-class UI
- fake hero sections
- dark terminal dashboards
- unexplained badges
- controls without outcomes

## Immediate Implementation Order

1. Web and native vocabulary cleanup:
   replace `chunks`, `journal`, and `sha` first-screen labels with human labels.
2. Model manager:
   model recommendation, installed/download state, active model selector, and
   Intel default path.
3. Workbench shell:
   native SwiftUI sidebar, center recorder/transcript, inspector.
4. Demo and preview:
   one click must populate recording, transcript, summary, decisions, risks,
   tasks, chunks, recovery state, and export.
5. Recovery center:
   human status first, technical disclosure second.
6. Transcript editor:
   timestamped segments, editable final transcript, source/provenance boundary.
7. Hotkeys:
   native recorder UI for toggle, push-to-talk, marker, cancel.
8. Export:
   markdown, plain text, JSON, SRT/VTT.
9. Local AI summaries:
   local summarizer provider contract, model selector, and clear unsupported
   states.
10. Distribution:
   signed DMG, Sparkle update path, first-launch update behavior.

## Design QA Checklist

Before merging UI work:

- The first screen shows the main task, not diagnostics.
- The user can tell what works now.
- The user can tell which model is active.
- Local/offline/cloud state is visible.
- Recording, transcript, summary, tasks, and export are reachable in one flow.
- Technical recovery data is inspectable but not dominant.
- Text fits at narrow and wide widths.
- Keyboard navigation and focus states are visible.
- Light and dark mode both work.
- Empty, recording, processing, finalized, error, and recovery states are all
  designed.
- The Mac UI is not just a stretched web layout.
