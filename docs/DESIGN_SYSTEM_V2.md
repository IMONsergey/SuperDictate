# SuperDictate Design System v2

Status: normative product design contract.

Last reviewed: 2026-08-08.

## Intent

SuperDictate must feel like a small, calm, first-class macOS application even when the product becomes technically powerful underneath.

The visual target is not a dashboard, admin panel, AI control center, or a literal clone of Pocket or ChatGPT. The product should combine:

- the lightness and single-purpose screen logic seen in Pocket / HeyPocket;
- the token architecture and typographic restraint demonstrated by OpenAI Apps SDK UI;
- native Apple platform behavior, system typography, semantic colors, materials, menus, keyboard navigation, sheets and window conventions;
- SuperDictate's own local-first identity.

The interface should make advanced capability disappear until the user needs it.

## Reference hierarchy

When references conflict, use this order:

1. Apple Human Interface Guidelines and native platform behavior.
2. This SuperDictate design contract and tokens.
3. Product task clarity and accessibility.
4. OpenAI Apps SDK UI token architecture and restraint.
5. Pocket / HeyPocket interaction references.
6. Decorative preference.

Primary references:

- Apple HIG: https://developer.apple.com/design/human-interface-guidelines/
- Apple macOS guidance: https://developer.apple.com/design/human-interface-guidelines/designing-for-macos/
- Apple sidebars: https://developer.apple.com/design/human-interface-guidelines/sidebars
- Apple typography: https://developer.apple.com/design/human-interface-guidelines/typography
- Apple color: https://developer.apple.com/design/human-interface-guidelines/color
- OpenAI Apps SDK UI: https://github.com/openai/apps-sdk-ui
- OpenAI public design guidance: https://openai.com/brand/
- Pocket product: https://heypocket.com/
- Pocket docs: https://docs.heypocketai.com/docs

OpenAI's visual trademarks and branded font are not SuperDictate assets. Do not copy the OpenAI logo, ChatGPT identity, OpenAI wordmark, or create an imitation brand. The useful reference is the design-system structure: primitives -> semantic aliases -> component tokens, restrained typography, semantic text levels, generous space, and minimal boilerplate.

## Core principles

### 1. One obvious thing at a time

Every primary screen has one dominant job.

- Today: understand what needs attention.
- Library: find and open a recording.
- Tasks: verify and finish extracted actions.
- Ask: ask memory a question.
- Recording detail: understand one recording.
- Capture overlay: record, pause, mark, stop.

Do not expose the complete feature graph at once.

### 2. Capture is an action, not a destination

Recording is available from:

- global hotkey;
- menu bar;
- toolbar primary action;
- Dock/menu commands where appropriate;
- platform-native quick surfaces on mobile/wearables.

There is no permanent `Capture` section in the main sidebar.

### 3. Content before chrome

Transcript, summary, tasks and answers are the product. The surrounding UI should recede.

Prefer:

- whitespace;
- typographic hierarchy;
- lists;
- subtle separators;
- native controls;
- contextual menus;
- progressive disclosure.

Avoid:

- colored card grids;
- decorative gradients;
- large persistent status strips;
- metric dashboards;
- boxed sections when spacing alone works;
- permanent inspectors;
- duplicated navigation.

### 4. Native before custom

On macOS use SwiftUI/AppKit system components before drawing replacements.

Use:

- system window chrome;
- system toolbar;
- system sidebar/split view;
- SF Pro through system font APIs;
- SF Symbols;
- semantic system colors;
- native sheets, menus, context menus, alerts and settings scenes;
- focus rings and keyboard navigation;
- system accent color for interactive emphasis where appropriate.

Custom UI is justified only when it represents a product-specific interaction, such as the recording HUD, waveform or evidence jump.

### 5. Progressive disclosure

Advanced features remain available without competing with the default flow.

Examples:

- model details live in Settings > Models;
- checksums and recovery journals live behind Technical Details;
- inference confidence appears when relevant or requested;
- speaker merge is contextual to a recording/person;
- export options open from Export rather than occupying permanent chrome;
- inspector appears on demand and remembers user preference.

### 6. Local-first status is quiet but trustworthy

Do not plaster `local`, `private`, `offline`, model names and storage state across every surface.

Normal healthy states remain quiet. Surface status when:

- the user explicitly inspects it;
- the state changes;
- processing is blocked;
- cloud access is about to occur;
- recovery is required;
- data may be deleted or moved.

### 7. Evidence without visual noise

AI-generated summary points, decisions and tasks can link back to source moments, but the source link should behave like a citation/footnote, not like a large card.

### 8. Motion explains state

Motion is functional, brief and interruptible.

Use motion for:

- recording start/stop;
- processing state change;
- insertion success;
- opening contextual detail;
- lightweight reordering.

Do not use looping decorative animation in reading surfaces.

## Information architecture

### Main sidebar

Only four primary destinations:

1. Today
2. Library
3. Tasks
4. Ask

Optional temporary/contextual groups may appear for saved searches or projects, but they must not turn the sidebar into a feature inventory.

Not top-level destinations:

- Capture — global action.
- AI Review — part of a recording detail.
- Transcript — part of a recording detail.
- People — library filter/entity view.
- Models — Settings.
- Recovery — Library/Settings contextual state.
- Settings — standard application Settings command/window.

### Toolbar

Default toolbar should be sparse:

- show/hide sidebar;
- current view title;
- search when relevant;
- one primary record control;
- a small contextual action group such as share/export/more.

Do not put model selectors, runtime pills, debug controls or pipeline steps in the main toolbar.

### Today

Today is a calm actionable list, not a dashboard.

Order:

1. primary Record action when nothing urgent exists;
2. items that need review or recovery;
3. tasks due/unscheduled;
4. recent recordings.

No metric cards by default.

### Library

Default presentation is a native list with search and filters.

Each row can show:

- title;
- time/date;
- duration;
- people or source context;
- one quiet state indicator when processing/recovery needs attention.

Opening a row reveals recording detail.

### Recording detail

Use a document-like reading surface.

Header:

- editable title;
- date/time and duration;
- people;
- playback;
- minimal share/more actions.

Primary content switcher:

- Summary
- Transcript
- Tasks

`Ask this recording` is an action that opens the Ask surface scoped to the recording rather than becoming a fourth dense panel.

Summary should read like a well-written note, not a set of cards.

Transcript should read like a transcript, with timestamps/speakers visually secondary.

Tasks should look like a checklist.

### Ask

Ask is intentionally simple:

- scope selector;
- conversation;
- source citations;
- composer.

Default scope follows context. If Ask is opened from a recording, scope that recording automatically. If opened globally, default to recent/all memory depending on the last user choice.

### Settings

Settings sections:

- General
- Recording & Hotkeys
- Models
- Language & Text
- Storage & Privacy
- Export & Integrations
- Updates (Direct edition)
- Advanced / Diagnostics

## Pocket mechanics to preserve

Pocket demonstrates several useful simplifications:

- summary as a clean document;
- tasks as a checklist rather than a project-management board;
- Ask as one focused conversation;
- languages/templates as simple searchable lists;
- recording as one-button behavior;
- generated outputs available after capture without forcing configuration first.

SuperDictate should improve on this by keeping capture software-native, local-first, exportable and evidence-backed.

## OpenAI-inspired design-system architecture

SuperDictate tokens use three layers.

### Primitive tokens

Raw scales only. Components must not normally reference them directly.

Examples:

- neutral palette;
- semantic status palettes;
- spacing scale;
- type sizes/weights;
- radius scale;
- motion durations;
- raw alpha values.

### Semantic tokens

Describe intent, not appearance.

Examples:

- `color.text.primary`
- `color.text.secondary`
- `color.surface.canvas`
- `color.surface.secondary`
- `color.border.subtle`
- `color.action.primary`
- `color.status.recording`
- `space.content.gutter`
- `type.body`

Native implementations should map semantic color tokens to Apple semantic APIs whenever possible rather than hard-coded RGB values.

### Component tokens

Only when a component requires stable custom geometry or behavior.

Examples:

- recording HUD corner radius;
- recording HUD padding;
- transcript speaker-column width;
- floating overlay shadow;
- compact toolbar control size.

Do not create component tokens merely to rename semantic tokens.

## Typography

### Native Apple products

Use the system SF family through platform APIs. Do not bundle OpenAI Sans as the application UI font.

Default hierarchy:

- Display: 28/34 semibold — rare hero/empty state only.
- Title: 20/26 semibold — main content title.
- Heading: 16/22 semibold — section heading.
- Body: 15/22 regular — transcript-adjacent prose and summaries.
- UI: 13/18 regular or medium — controls and rows.
- Caption: 12/16 regular — metadata.
- Mono: system monospaced font only for timestamps, technical IDs and logs.

Use Semibold as the normal emphasis weight. Avoid excessive Bold and avoid Light for small text.

### Web preview

Use the system stack to stay visually close to native platforms. The preview exists to validate information architecture and interaction, not to establish a separate web brand.

## Color

Default product surfaces are neutral.

Native:

- use semantic system background, label, secondary label, separator and fill colors;
- use the user's system accent for generic selection/action emphasis;
- use red only for recording/destructive state;
- use green only for success/verified state;
- use orange/yellow only for warnings;
- never use purple/blue merely to make AI features look "AI".

Web fallback tokens exist for deterministic preview rendering, but should preserve the same semantic hierarchy.

## Spacing

Primitive rhythm: 4 pt.

Preferred scale:

- 4 — micro gap
- 8 — inline gap
- 12 — compact control/list gap
- 16 — standard component padding
- 20 — comfortable row/content gap
- 24 — section gap
- 32 — large section separation
- 40 — empty-state/major whitespace

Avoid nesting 16 px padding inside multiple bordered cards; whitespace is not permission to create containers.

## Radius

Native standard controls use platform defaults.

Custom surfaces:

- 6 — compact custom controls
- 10 — grouped custom surface
- 14 — floating recording/HUD surface
- 999 — capsule only when the shape communicates state or compact action

Do not make every container a pill.

## Elevation

Default elevation is none.

Use shadows only for true floating layers:

- recording HUD;
- popover-like custom overlay;
- drag preview.

A bordered or tonal surface is preferable to a shadowed card in normal document flow.

## Motion

Durations:

- fast: 120 ms
- standard: 180 ms
- deliberate: 240 ms
- HUD enter: up to 280 ms

Use native spring/animation defaults when they provide correct platform feel. Respect Reduce Motion.

## Component families

Keep the custom component library intentionally small:

- PrimaryAction
- QuietAction
- DestructiveAction
- SearchField wrapper only when native search is unavailable
- ListRow
- RecordingHUD
- RecordingControlCluster
- TranscriptSegment
- EvidenceLink
- TaskRow
- ProcessingStatusRow
- EmptyState
- ModelRow
- RecoveryRow

Before adding a new component family, verify that a system component cannot do the job.

## Hard rejection rules

A design fails review if it contains any of the following without a strong product reason:

- dashboard metric cards on the default home screen;
- a permanent five-step processing strip;
- more than five primary sidebar destinations;
- a permanent right inspector that duplicates visible content;
- model selection in the main toolbar;
- debug/JSON/export-to-JSON controls in primary chrome;
- decorative gradients behind productivity content;
- multiple simultaneous primary buttons;
- card-in-card layouts;
- gratuitous status pills;
- custom traffic-light window controls in the native app;
- OpenAI/ChatGPT branding or a visually confusing imitation;
- a Pocket clone rather than SuperDictate's own information hierarchy.

## Validation checklist

Every redesigned surface must pass:

- Can a new user identify the one primary action in under two seconds?
- Can the same task be completed with keyboard navigation where macOS users expect it?
- Does the view still work in dark mode and increased contrast?
- Is at least one layer of visual container removable without losing hierarchy? If yes, remove it.
- Are healthy technical states silent?
- Are destructive/cloud/network transitions explicit?
- Does the interface use native controls before custom replacements?
- Does the content remain readable at narrow window widths?
- Is every visible control functional?
- Is the current surface simpler than the PR #19 workbench preview it replaces?

## Immediate implementation order

1. Introduce machine-readable design tokens.
2. Rework the web preview to validate the four-destination IA and recording-detail model.
3. Remove the current workflow strip, permanent lens/session panels and dashboard-card home.
4. Rebuild native SwiftUI navigation using `NavigationSplitView`, native toolbar and Settings.
5. Rebuild the recording detail around Summary / Transcript / Tasks.
6. Rebuild recording HUD from semantic/component tokens.
7. Add dark/high-contrast/reduced-motion QA.
8. Only after the basic UX is quiet and correct, expose advanced model, recovery, evidence and integration surfaces through progressive disclosure.
