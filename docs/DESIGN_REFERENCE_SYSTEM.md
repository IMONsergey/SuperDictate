# SuperDictate Design Reference System

Status: active design contract for the macOS workbench, native clients, and web
preview.

Last source review: 2026-07-30.

Detailed research:

- [NATIVE_DESIGN_RESEARCH.md](NATIVE_DESIGN_RESEARCH.md)
- [POCKET_ALTERNATIVE_PRODUCT_RESEARCH.md](POCKET_ALTERNATIVE_PRODUCT_RESEARCH.md)

## Product Design Verdict

SuperDictate must feel like a real local-first Mac utility and a native
cross-platform capture product, not a web dashboard. The product target is an
app-only alternative to Pocket / HeyPocket AI: capture conversations anywhere,
process them locally first where possible, and turn them into trusted memory and
follow-through.

The product loop is:

Capture -> process -> review -> execute -> remember.

Everything else exists to support that path: model choice, recovery, storage,
privacy, hotkeys, evidence links, tasks, calendar, Ask, export, and advanced
inspection.

## Source Of Truth

- Apple Human Interface Guidelines:
  https://developer.apple.com/design/human-interface-guidelines/
- Apple Design Resources:
  https://developer.apple.com/design/resources/
- Apple Style Guide:
  https://help.apple.com/applestyleguide/
- SF Symbols:
  https://developer.apple.com/sf-symbols/

Use official Apple platform patterns first: toolbar, sidebar, inspector,
settings, menus, keyboard shortcuts, focus rings, system typography, semantic
colors, accessibility labels, and adaptive layouts.

## Product References

- CodeEdit: https://github.com/CodeEditApp/CodeEdit
  - Borrow: Mac-native workbench structure, welcome window thinking, toolbar
    density, and reusable SwiftUI window packages.
  - Avoid: building a code-editor-shaped app. SuperDictate is a recorder and
    transcript workbench.
- CotEditor: https://github.com/coteditor/CotEditor
  - Borrow: restraint, text-editor quality, familiar macOS controls, keyboard
    behavior, localization, and accessibility.
  - Avoid: burying recording and AI workflow under generic editor chrome.
- NetNewsWire: https://github.com/Ranchero-Software/NetNewsWire
  - Borrow: sidebar hierarchy, reading comfort, multi-window Mac behavior, empty
    states, and keyboard navigation.
  - Avoid: feed-reader information architecture.
- IceCubesApp: https://github.com/Dimillian/IceCubesApp
  - Borrow: multiplatform SwiftUI navigation, sidebar adaptation, draft-like
    persistence, cached state, and live updates.
  - Avoid: social-client density and feed-first composition.
- Pindrop: https://github.com/watzon/pindrop
  - Borrow: local dictation posture, model browser, hotkeys, output modes,
    transcript history, custom dictionary, and first-run model setup.
  - Avoid: menu-bar-only product scope. SuperDictate also needs a full workbench.

## Technology References

- Argmax OSS Swift: https://github.com/argmaxinc/argmax-oss-swift
  - Borrow for Apple Silicon direction: WhisperKit, SpeakerKit, TTSKit, and
    local speech AI package boundaries.
- KeyboardShortcuts: https://github.com/sindresorhus/KeyboardShortcuts
  - Borrow for user-configurable global shortcuts and settings UI.
- Sparkle: https://github.com/sparkle-project/Sparkle
  - Borrow for native update trust, beta channels, and quiet first-launch
    behavior once distribution begins.
- Fluent UI Apple tokens:
  https://github.com/microsoft/fluentui-apple/wiki/Design-Tokens
  - Borrow only the token hierarchy idea: global tokens, semantic alias tokens,
    and control tokens. Do not copy Fluent's visual style.

## Non-Negotiable Interface Rules

1. No raw JSON as a primary product surface. Technical data belongs in disclosure
   sections and inspector details.
2. No fake controls. Every visible control must either work or be explicitly
   marked as preview/runtime-unavailable.
3. No marketing landing page. The first screen is the usable recorder/workbench.
4. No colored card soup. Use native hierarchy, typography, separators, and
   system materials before decorative cards.
5. No hidden model choice. The active model, recommendation, installed state,
   size, speed, privacy mode, and download state must be visible.
6. No surprise cloud. Local/open-source/free is default; cloud or paid providers
   require explicit opt-in and clear copy.
7. No destructive ambiguity. Delete, crash simulation, model removal, and reset
   actions must use destructive styling and confirmation where data can be lost.

## Native Information Architecture

### First Launch

- Microphone permission
- Local model selection and download
- Optional global hotkey setup
- Storage location and privacy explanation
- Start recording

### Main Mac Window

- Sidebar: Today, Capture, Library, Tasks, Ask, People, Models, Settings
- Toolbar: record, stop, lens selector, model selector, search, export, share
- Center: capture surface, recording detail, transcript/editor, speaker
  segments, timeline, AI review, mind map, task checklist
- Inspector: active model, local runtime, processing state, evidence, exports,
  recovery, provenance, technical details

### Menu Bar

- Current recording state
- Quick record and stop
- Push-to-talk status
- Last transcript copy/export actions
- Open workbench

### Settings

- Models
- Recording
- Hotkeys
- Output and export
- Local AI cleanup and summaries
- Storage and recovery
- Privacy
- Updates

## Visual System Rules

- Typography: SF Pro/Text for interface and transcript, SF Mono only for
  timestamps, checksums, logs, and code-like metadata.
- Spacing: 4 pt rhythm, with 8/12/16/24/32 pt as the common scale.
- Radius: controls follow platform defaults; custom cards stay at 8 pt or less.
- Color: system neutrals as the base, Apple blue for primary action, green for
  verified/local, amber for warning, red for destructive. Do not let the app
  become one-hue blue, purple, beige, or dark-slate.
- Icons: SF Symbols or a native icon library only. Use text labels where the
  action is unfamiliar.
- Motion: subtle state transitions for recording, processing, and completion.
  No decorative motion that competes with transcript reading.
- Density: Mac is information-dense but calm; iPhone/watch surfaces are capture
  and review only.

## Immediate Repair Backlog

1. Reframe the product around Today, Capture, Library, AI Review, Tasks, Ask,
   People, Models, and Settings.
2. Add a real model manager:
   Recommended for this Mac, installed, needs download, source, size, speed,
   accuracy, language support, privacy mode, and actions.
3. Make demo mode exercise the full product loop:
   capture, processing, transcript, evidence-backed summary, decisions, risks,
   tasks, calendar scheduling, Ask, model choice, recovery, and export.
4. Replace recovery JSON-first UI with human recovery states and a technical
   details disclosure.
5. Add lens selector, Ask scope chips, speaker/person management, mind map
   preview, and task evidence links to the web preview before rebuilding the
   native shell.
6. Build the native SwiftUI workbench shell from this information architecture.
7. Keep the web preview aligned with the native workbench until the native Intel
   build is stable enough for daily testing.
