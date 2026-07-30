# SuperDictate Design Reference System

Status: active working brief for the macOS workbench and web preview.

## Primary Sources

- Apple Human Interface Guidelines: https://developer.apple.com/design/human-interface-guidelines/
- Apple Design Resources: https://developer.apple.com/design/resources/
- SF Symbols: https://developer.apple.com/sf-symbols/
- Apple Design videos: https://developer.apple.com/design/

## Open-Source Product References

- CodeEdit: https://github.com/CodeEditApp/CodeEdit
  - Use for macOS-native workbench structure: toolbar, sidebar, inspector,
    detail workspace, preferences, command density, and native SwiftUI/AppKit
    expectations.
- CotEditor: https://github.com/CotEditor/CotEditor
  - Use for restraint: standard macOS controls first, low visual noise, clear
    beginner/advanced balance.
- NetNewsWire: https://github.com/Ranchero-Software/NetNewsWire
  - Use for mature macOS/iOS split views, reading hierarchy, empty states, and
    long-session comfort.
- IceCubesApp: https://github.com/Dimillian/IceCubesApp
  - Use for multiplatform SwiftUI navigation, sidebar behavior, drafts,
    streaming updates, and iOS/macOS adaptation.
- Pindrop: https://github.com/watzon/pindrop
  - Use as the closest dictation-domain reference: model browser, local-first
    transcription, privacy posture, hotkeys, and diarization roadmap.
- Argmax OSS Swift: https://github.com/argmaxinc/argmax-oss-swift
  - Use for native on-device speech AI direction: WhisperKit, SpeakerKit, TTSKit,
    and local server patterns.
- Fluent UI Apple: https://github.com/microsoft/fluentui-apple
  - Use only for token architecture ideas when building cross-platform native
    component contracts. Do not visually turn SuperDictate into Fluent.

## Design Principles For SuperDictate

1. Native first: toolbar, sidebar, inspector, split view, settings, menus, and
   keyboard shortcuts must feel like a real macOS utility, not a web dashboard.
2. One primary path: Record -> Text -> AI summary -> Tasks -> Export. Every
   screen state should make the next action obvious without a tutorial.
3. Local trust: model, storage, recovery, checksum, and privacy status are
   visible in the inspector, not hidden in logs.
4. Progressive depth: normal users see record/text/summary/tasks; advanced users
   can inspect chunks, model runtime, recovery journal, and export JSON.
5. Quiet but distinctive: mostly system neutrals, Apple blue for primary action,
   green for verified/local, amber for caution, red only for destructive states.
6. No fake affordances: a button must do something; preview-only limitations must
   be labeled as preview/runtime status rather than disguised as production.

## Immediate UX Repairs

- Replace technical-first labels like `Chunks` and `Recovery Journal` with
  user-facing labels, while retaining inspectable technical details.
- Keep the first viewport focused on the recorder controls and current status.
- Make model choice permanent top-level context, not a hidden setting.
- Make the demo flow populate transcript, AI summary, decisions, risks, tasks,
  chunks, and recovery state so the product can be evaluated without microphone
  permissions.
- Keep the web preview visually close to the planned macOS workbench so it is
  useful for product review before native Intel runtime is fully stable.
