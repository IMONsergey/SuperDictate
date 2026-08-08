# SuperDictate Design Reference System

Status: active reference index.

Last source review: 2026-08-08.

The normative visual and interaction contract is now:

- [DESIGN_SYSTEM_V2.md](DESIGN_SYSTEM_V2.md)
- [`design/superdictate.tokens.json`](../design/superdictate.tokens.json)

Supporting research:

- [NATIVE_DESIGN_RESEARCH.md](NATIVE_DESIGN_RESEARCH.md)
- [POCKET_ALTERNATIVE_PRODUCT_RESEARCH.md](POCKET_ALTERNATIVE_PRODUCT_RESEARCH.md)

## Product design verdict

SuperDictate should be technically deep and visually quiet.

The product is not a dashboard and must not expose its architecture as its interface. It is a native local-first capture and memory utility whose default loop is:

```text
Record -> receive useful text -> review only when needed -> act
```

Long-form conversation intelligence remains part of the product, but it is progressively disclosed rather than presented as a permanent multi-panel workbench.

## Source hierarchy

1. Apple Human Interface Guidelines and native macOS behavior.
2. SuperDictate Design System v2 and semantic tokens.
3. Accessibility and task clarity.
4. OpenAI Apps SDK UI design-system architecture and visual restraint.
5. Pocket / HeyPocket interaction simplicity.
6. Other product references.

Primary sources:

- Apple HIG: https://developer.apple.com/design/human-interface-guidelines/
- Apple macOS guidance: https://developer.apple.com/design/human-interface-guidelines/designing-for-macos/
- Apple sidebars: https://developer.apple.com/design/human-interface-guidelines/sidebars
- Apple typography: https://developer.apple.com/design/human-interface-guidelines/typography
- Apple color: https://developer.apple.com/design/human-interface-guidelines/color
- OpenAI Apps SDK UI: https://github.com/openai/apps-sdk-ui
- OpenAI design guidance: https://openai.com/brand/
- Pocket: https://heypocket.com/
- Pocket docs: https://docs.heypocketai.com/docs

## What we take from OpenAI

Use the architecture and restraint, not OpenAI branding.

Borrow:

- primitive -> semantic -> component token hierarchy;
- semantic text/surface/border/action/status roles;
- small number of typography weights;
- generous whitespace;
- short actionable copy;
- minimal component chrome;
- dark-mode-aware semantic tokens;
- accessibility as a design-system responsibility.

Do not copy:

- OpenAI/ChatGPT logos or wordmarks;
- OpenAI product naming;
- OpenAI Sans as SuperDictate's bundled product font;
- distinctive ChatGPT branding that could imply affiliation.

## What we take from Pocket

Pocket is useful primarily as a complexity benchmark.

Borrow:

- one clear purpose per screen;
- summary rendered like a document;
- tasks rendered like a checklist;
- Ask rendered like one simple conversation;
- language/template choices rendered as searchable lists;
- one-action recording behavior;
- automatic outputs after capture without mandatory pre-configuration.

Improve:

- no hardware dependency;
- better desktop keyboard/hotkey ergonomics;
- local-first processing and ownership;
- source/evidence links;
- first-class export;
- stronger recovery transparency;
- native Mac integration.

## Revised native information architecture

### Main sidebar

Only four default primary destinations:

- Today
- Library
- Tasks
- Ask

`Capture` is a global action, not navigation.

`Summary`, `Transcript`, and recording-specific tasks live inside Recording Detail.

`People` is a Library filter/entity view.

`Models`, privacy, storage, updates and diagnostics live in Settings.

### Main toolbar

Default toolbar contains only:

- sidebar toggle;
- current view title;
- search when relevant;
- record control;
- compact contextual share/export/more actions.

Never place the following in default primary chrome:

- model selector;
- runtime/debug status pill;
- five-step processing strip;
- JSON actions;
- lens inventory;
- recovery internals.

### Recording detail

The reading surface has three primary modes:

- Summary
- Transcript
- Tasks

The detail should resemble a clean document more than a dashboard.

`Ask this recording` opens Ask with the recording preselected as scope.

An inspector may appear on demand for metadata, model/provenance and advanced detail, but is not permanently open by default.

### Settings

- General
- Recording & Hotkeys
- Models
- Language & Text
- Storage & Privacy
- Export & Integrations
- Updates, where edition permits
- Advanced / Diagnostics

## Non-negotiable rules

1. Native components before custom replicas.
2. System typography on Apple platforms.
3. Semantic colors before hard-coded colors.
4. One visually dominant action per primary surface.
5. Healthy technical state stays quiet.
6. Cloud/network transitions are explicit.
7. No decorative `AI` color language.
8. No card grids for information that can be a list or document.
9. No fake controls.
10. No marketing hero in the application.
11. No permanent inspector unless the user chooses to keep it open.
12. No OpenAI or Pocket visual cloning.

## Current implementation verdict

PR #19 (`feature/pocket-workbench-interface`) is useful as a functional experiment but is not the target UI.

Its persistent top controls, workflow strip, large feature sidebar, Lens panel, Session panel, dashboard cards and three-column workbench violate the new design contract. It should be treated as a behavior inventory and superseded by a lightweight interface implementation rather than polished in place.

## Immediate implementation backlog

1. Keep `design/superdictate.tokens.json` as the machine-readable token source.
2. Build platform adapters for tokens rather than scattering color/spacing literals.
3. Rebuild the web preview around Today / Library / Tasks / Ask so the information architecture can be validated quickly.
4. Replace the web dashboard home with a simple actionable list.
5. Replace the permanent workflow strip with contextual processing status.
6. Replace the permanent lens/session/model panels with menus, settings and disclosure.
7. Rebuild native SwiftUI navigation with `NavigationSplitView`, native toolbar and Settings.
8. Rebuild recording detail around Summary / Transcript / Tasks.
9. Apply the same token semantics to the recording HUD.
10. Validate light, dark, increased-contrast and Reduce Motion behavior before visual polish.
