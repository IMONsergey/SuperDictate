# SuperDictate Design System v2

Status: **normative product design contract**.

Last reviewed: 2026-08-08.

## Intent

SuperDictate must feel like a small, calm, first-class macOS application even when the product becomes technically powerful underneath.

The target is not a dashboard, an admin panel, an AI control center, or a literal clone of Pocket or ChatGPT. SuperDictate combines:

- the lightness and single-purpose screen logic seen in Pocket / HeyPocket;
- the token architecture and typographic restraint demonstrated by modern systems such as OpenAI Apps SDK UI;
- native Apple platform behavior, system typography, semantic colors, materials, menus, keyboard navigation, sheets and window conventions;
- SuperDictate's own local-first identity and voice workflow.

The interface should make advanced capability disappear until the user needs it.

## Reference hierarchy

When references conflict, use this order:

1. Apple Human Interface Guidelines and native macOS behavior.
2. This SuperDictate design contract and its machine-readable tokens.
3. Product task clarity, accessibility and reliability.
4. OpenAI-style semantic token architecture and visual restraint.
5. Pocket / HeyPocket interaction references and reduction of complexity.
6. Decorative preference.

OpenAI visual trademarks, logo, wordmark and branded font are not SuperDictate assets. Pocket is a product-behavior reference, not a template. We borrow principles and mechanics, never another product's identity.

## Product model

SuperDictate serves two jobs on one trusted local-first runtime.

### Instant Dictation

`Hotkey -> speak -> text appears where the cursor is.`

This is an almost invisible interaction. The product should get out of the way. The visible surface is primarily the recording HUD, status feedback and contextual recovery when something fails.

### Memory Capture

`Capture -> transcript -> summary -> tasks -> ask.`

This job uses the main application window. It turns meetings, conversations and thoughts into durable searchable memory and follow-through.

Do not force both jobs into the same screen hierarchy. They share data, vocabulary, models, privacy rules and processing, but the interaction surfaces are different.

## Core principles

### 1. One obvious thing at a time

Every primary screen has one dominant job.

- Today: understand what needs attention.
- Library: find and open a recording.
- Tasks: verify and finish extracted actions.
- Ask: ask memory a question.
- Recording detail: understand one recording.
- Capture HUD: record, stop and understand state.

Do not expose the complete feature graph at once.

### 2. Capture is an action, not a destination

Recording is available from:

- global hotkey;
- menu bar;
- main toolbar primary action;
- native menu commands;
- platform-native quick surfaces on future mobile/wearable clients.

There is no permanent `Capture` section in the primary sidebar.

### 3. Content before chrome

Transcript, summary, tasks and answers are the product. Surrounding interface recedes.

Prefer:

- whitespace;
- typographic hierarchy;
- native lists;
- subtle separators;
- native controls;
- contextual menus;
- progressive disclosure.

Avoid:

- colored card grids;
- decorative gradients;
- giant hero copy inside a utility app;
- persistent status strips;
- metric dashboards;
- boxed sections when spacing alone works;
- permanent inspectors;
- duplicated navigation;
- engineering terminology in default UI.

### 4. Native before custom

On macOS use SwiftUI/AppKit system components before drawing replacements.

Default building blocks:

- system window chrome;
- `NavigationSplitView` / native sidebar;
- system toolbar;
- system font APIs;
- SF Symbols;
- semantic system colors;
- native sheets, menus, context menus, alerts and Settings;
- focus rings and keyboard navigation;
- system accent color for generic interactive emphasis.

Custom UI is justified only when it represents a product-specific interaction, especially:

- recording HUD;
- live audio waveform/input health;
- evidence jump from generated output to transcript/audio;
- voice-specific capture state.

### 5. Progressive disclosure

Advanced capability remains available without competing with the default flow.

Examples:

- model management lives in Settings > Models;
- checksums and recovery journals live behind Technical Details;
- inference confidence appears only where meaningful;
- speaker merge is contextual to a recording/person;
- export choices open from Export/Share;
- an inspector appears only on demand;
- cloud-provider controls remain in Settings until a workflow explicitly needs them.

### 6. Healthy local-first state stays quiet

Do not plaster `local`, `private`, `offline`, model names and storage state across every surface.

Show infrastructure status when:

- the user explicitly inspects it;
- a state changes materially;
- processing is blocked;
- cloud access is about to occur;
- recovery is required;
- data may be deleted or moved;
- a model must be downloaded or replaced.

### 7. Evidence without visual noise

Generated summary points, decisions and tasks may link to source moments. Evidence behaves like a citation/footnote or subtle source affordance, not a giant provenance card.

A generated claim must never look more authoritative than its source warrants.

### 8. Motion explains state

Motion is functional, brief and interruptible.

Use it for:

- recording start/stop;
- processing transitions;
- insertion success;
- contextual detail presentation;
- light reordering.

Do not use looping decorative animation in reading surfaces. Respect Reduce Motion.

## Primary information architecture

### Main sidebar

Only four primary destinations:

1. Today
2. Library
3. Tasks
4. Ask

Optional contextual groups may later appear for projects or saved searches, but the sidebar must never become a feature inventory.

Not top-level destinations:

- Capture — global action.
- AI Review — part of recording detail.
- Transcript — part of recording detail.
- People — Library entity/filter.
- Models — Settings.
- Recovery — contextual Library/Settings state.
- Settings — standard application Settings command/window.

### Toolbar

Default toolbar is sparse:

- native sidebar control supplied by the platform;
- current view/window title;
- search when relevant;
- one primary Record/Stop action;
- a small contextual Share/Export/More group where needed.

Forbidden from the default toolbar:

- model selector;
- runtime health pill;
- debug/demo buttons;
- processing pipeline steps;
- storage counters;
- permanent privacy badges.

### Today

Today is a calm actionable list, never a dashboard.

Order of priority:

1. active recording/processing state;
2. recovery or review that actually needs user action;
3. open tasks;
4. recent recordings;
5. a primary Record action when the surface would otherwise be empty.

No metric cards by default.

### Library

Library is a native list with search/filter capability.

A row may show:

- title;
- date/time;
- duration;
- people/context when useful;
- one quiet attention indicator.

Opening a row reveals recording detail.

### Recording detail

The recording is a document, not a dashboard.

Header:

- editable title eventually;
- date/time and duration;
- people when known;
- playback when audio exists;
- minimal contextual actions.

Primary content switcher:

- Summary
- Transcript
- Tasks

`Ask this recording` opens Ask already scoped to this recording instead of adding a fourth dense panel.

Summary reads like a well-written note.
Transcript reads like a transcript.
Tasks look like a checklist.

### Tasks

Tasks are not decorative AI bullets. A real task can eventually carry:

- title;
- source recording;
- source excerpt/evidence;
- owner when explicitly known;
- due date when explicitly known or confirmed;
- completion state;
- calendar/export action.

Never invent owner or deadline and silently present it as fact.

### Ask

Ask ships only when answers can be grounded in source data.

Target composition:

- scope selector;
- conversation;
- compact source citations;
- composer.

Default scope follows context. Opening Ask from a recording scopes to that recording; opening globally uses the last sensible global scope.

Until evidence-backed retrieval exists, show a truthful unavailable state rather than a fake chat demo in production UI.

## Settings architecture

Use the standard macOS Settings window. Proposed sections:

### General

- interface language;
- launch behavior;
- menu bar / Dock behavior;
- default recording behavior.

### Recording

- primary shortcut;
- alternate completion shortcut;
- history shortcut;
- input device;
- completion behavior;
- feedback sounds;
- recording HUD behavior.

### Models

- recommended active speech model;
- installed models;
- model size and supported languages;
- download/remove actions;
- advanced quality/speed choice;
- later: local summarization/search models.

Do not expose this inventory in the main toolbar.

### Vocabulary & Text

- corrections;
- filler removal;
- snippets;
- processing/output modes as they mature.

### Storage & Privacy

- data location;
- history retention;
- audio retention;
- export/delete controls;
- local vs optional cloud policy;
- clear explanation of what leaves the Mac.

### Advanced

- recovery tools;
- diagnostics;
- technical details;
- experimental features.

### Updates

Direct edition only where appropriate.

## Design token architecture

Machine-readable source: `design/superdictate.tokens.json`.

Layers:

1. **Primitive** — raw spacing, radius, type size, motion duration and geometry values.
2. **Semantic** — roles such as primary text, secondary surface, action, recording, warning and section spacing.
3. **Component** — rare component-level aliases such as document width, sidebar width and floating HUD geometry.

A component must consume semantic roles whenever possible. Raw primitive values should not spread across production UI.

### Apple color rule

SwiftUI/AppKit resolves colors through semantic system APIs:

- label/secondary/tertiary label;
- window/control/under-page backgrounds;
- separator;
- control accent;
- system red/green/orange.

Literal light/dark values in the JSON are parity references for non-Apple previews, not a replacement for platform semantic color resolution.

### Typography

Use the system font.

- 28 pt semibold: rare display/empty-state title.
- 20 pt semibold: document/view title.
- 16 pt semibold: section heading.
- 15 pt regular: readable document body.
- 13 pt regular/medium: controls and rows.
- 12 pt regular: metadata.
- monospaced system style: timestamps, logs and code-like diagnostics only.

Do not use rounded display fonts as a generic AI aesthetic.

### Spacing

Primitive rhythm starts at 4 pt.

Common semantic spacing:

- inline: 8;
- compact: 12;
- component: 16;
- comfortable: 20;
- content gutter: 24;
- section: 32;
- major: 40.

Whitespace should create hierarchy before borders do.

### Radius

Prefer native control geometry. Custom radius is reserved for custom surfaces:

- compact: 6;
- surface: 10;
- floating: 14.

Do not turn every label, state or row into a capsule.

### Shadows

No default card shadow system. Native windows/materials already provide depth. Custom shadows must be justified by a floating layer such as the HUD.

## Recording HUD

The HUD is one of the few strongly custom surfaces because it represents an interaction macOS does not provide.

Healthy target states:

- idle: HUD absent;
- entering recording: quick scale/fade without bounce circus;
- recording: clear microphone activity and active state;
- transcribing: a quiet state transition, not a spinner dashboard;
- success: brief confirmation when useful;
- failure: visible actionable error without destroying transcript/audio.

The HUD must:

- remain legible over arbitrary app content;
- support Reduce Motion;
- avoid covering the focused text caret when possible;
- visually distinguish recording from transcription;
- never imply that text was inserted if insertion failed.

## Interaction rules

### Record

A record action must never lead first to a configuration screen when requirements are already satisfied.

### Stop

Stop must preserve captured audio/text even if downstream transcription or insertion fails.

### Processing

Do not show every pipeline stage by default. Use a single human state such as `Transcribing…`; technical stages belong in diagnostics.

### Success

When text was inserted successfully, avoid unnecessary modal confirmation. The inserted text is the confirmation.

### Failure

Failure copy answers:

1. what happened;
2. whether data is safe;
3. what the user can do next.

### Destructive actions

Delete/reset/remove-model actions use native destructive role and confirmation where loss is meaningful.

## Accessibility

Minimum requirements:

- VoiceOver labels for icon-only controls;
- keyboard access for all primary workflows;
- native focus rings;
- no state communicated only by color;
- sufficient contrast through semantic system colors;
- Dynamic Type-equivalent semantic sizing where platform conventions permit;
- Reduce Motion respected by custom HUD transitions;
- readable transcript selection/copy behavior.

## Localization

SuperDictate already supports Russian and English surfaces. New UI must not create a third hard-coded language architecture.

Implementation rule:

- product state remains language-neutral;
- user-facing strings move behind one localization/copy layer when the new shell is connected to runtime;
- layouts must tolerate Russian labels being longer than English labels;
- prompts/model instructions are not automatically translated when semantics depend on the original text.

## What we explicitly reject

Do not reintroduce these patterns without a new design decision:

- 8–12 permanent sidebar destinations;
- `Capture` as a sidebar page;
- global `AI Review` section;
- permanent right inspector;
- five-step workflow strip;
- cards for every fact;
- model selector in every toolbar;
- separate badges for every healthy infrastructure state;
- decorative gradients as a main identity device;
- fake Ask/chat UI before grounded retrieval exists;
- fake controls marked only in tiny print;
- debug JSON as a primary user surface;
- browser-like web dashboard conventions in the native Mac shell.

## Product-specific component inventory

Keep the custom inventory deliberately small.

### Required

- lightweight main shell;
- recording HUD;
- recording/list row;
- task row;
- document-like recording detail;
- transcript source/evidence link;
- permission/recovery callout;
- model row inside Settings.

### Use native components instead of custom versions

- buttons;
- toggles;
- segmented picker;
- lists;
- navigation split view;
- menus;
- search field;
- settings form;
- alerts;
- progress view;
- sheets;
- context menus.

## Implementation contract

The production implementation starts in the main Swift package:

- `SuperDictateCore` contains product-facing state and commands without AppKit/SwiftUI or ASR implementation details.
- `SuperDictateUI` consumes `SuperDictateCore` and owns the new native presentation layer and token adapter.
- `Parakey` remains the existing runtime adapter until low-level responsibilities are safely extracted.

The runtime should gradually become an adapter into the product state instead of the UI importing monolithic internals.

This boundary allows us to replace presentation without rewriting working audio, hotkey, CoreML, persistence, update or TCC code.

## Audit rule for every new screen

Before merging UI ask:

1. What is the one dominant job of this screen?
2. Which visible element can be removed without losing capability?
3. Is any technical state exposed that belongs in Settings/diagnostics?
4. Are we using a custom component where a native one exists?
5. Does the screen still make sense without color?
6. Does it work from keyboard?
7. Are empty/loading/error states truthful?
8. Does every generated claim have a path back to evidence where required?
9. Did we accidentally make the product feel more complex than the task?

If the answer to the last question is yes, simplify before adding polish.

## Near-term implementation sequence

1. Compile the new `SuperDictateCore` and `SuperDictateUI` next to the current runtime without behavior changes.
2. Connect a real main window to current runtime state.
3. Add proper bilingual copy/localization mapping.
4. Build native Settings with Models, Recording, Storage & Privacy and Advanced sections.
5. Apply the token system to the existing recording HUD while preserving its audio/thread invariants.
6. Extract deterministic text-processing/state logic from `main.swift` into Core behind regression tests.
7. Add a real Library data source and searchable durable storage.
8. Add evidence-backed Summary/Tasks.
9. Ship Ask only after grounded retrieval is real.

## Success criteria

The redesign is working when:

- a first-time user can understand how to record without reading documentation;
- an existing dictation user can continue using the global hotkey without opening the main window;
- the main window looks and behaves like a macOS application rather than a web dashboard;
- there are only four primary destinations;
- model/runtime/recovery complexity is absent from healthy default chrome;
- Summary and Transcript are comfortable to read for several minutes;
- every advanced capability remains reachable through context or Settings;
- adding a new model or backend does not require redesigning primary navigation;
- the app can grow dramatically under the hood without visually growing at the same rate.
