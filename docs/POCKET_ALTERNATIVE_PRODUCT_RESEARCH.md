# SuperDictate Pocket alternative product research

Status: active product research brief.

Last source review: 2026-07-30.

This document uses "Pocket" to mean HeyPocket / Pocket AI, the conversation
recorder and AI memory product. Mozilla Pocket, the read-it-later product, is a
different product category and is referenced only as a naming ambiguity.

## Executive read

SuperDictate is not trying to become a prettier timer with a transcript panel.
It is a cross-platform, app-only alternative to Pocket: a conversation capture
system that turns speech into trusted memory and follow-through.

The core product loop is:

```text
Capture -> process -> review -> execute -> remember
```

Pocket's advantage comes from hardware friction removal: physical button,
physical mode slider, status light, phone-backed sync, and one-tap task
scheduling. SuperDictate cannot copy the hardware, so it must win with
software-native capture surfaces:

- macOS menu bar, global hotkey, meeting overlay, native notifications, and
  local folder visibility;
- Windows tray, global hotkey, and native meeting overlay;
- iOS Action Button, Lock Screen widget, Control Center control, Share Sheet,
  Live Activity, and Shortcuts;
- Android Quick Settings tile, widget, Share Sheet, foreground service
  notification, and automation intents;
- watchOS and Wear OS complications, tiles, haptics, markers, and offline queue;
- web library, review, search, export, billing, admin, and integrations.

The strategic difference is local-first ownership. SuperDictate should default
to free/open-source local models where possible, show model choice explicitly,
store recordings locally first, and make cloud processing an opt-in acceleration
or sync layer.

## Competitive map

### Pocket / HeyPocket

Observed mechanics:

- one-press recording through a dedicated device;
- physical mode selection for calls and conversations;
- recording sync over Bluetooth, Wi-Fi quick transfer, or USB-C web/desktop
  sync;
- summary lenses such as Meeting, Discovery Call, Interview, Journaling, and
  Auto Detect;
- spoken labels such as decision, action item, and risk that become structured
  output;
- processing stages: upload, analyze, extract, write;
- summaries, action items, mind maps, Ask over recordings, speaker management,
  custom templates, tags, file attachments, integrations, API, webhooks, MCP,
  and calendar execution;
- "Day One" behavior: do not leave the app until important actions have time on
  the calendar.

What to copy:

- lens-first capture;
- source-linked action items;
- calendar close-loop;
- global Ask over recordings;
- speaker library with merge and global rename;
- mind map as a navigable overview;
- custom templates with section-level instructions;
- explicit sync and recovery states;
- native desktop meeting detection and quick controls.

What to improve:

- no hardware purchase or pairing dependency;
- offline capture on every device, not only the recorder;
- visible local model path and privacy mode;
- export-first user ownership;
- stronger parity across desktop, mobile, wearable, and web;
- native review interface instead of a generic web dashboard;
- evidence-first AI output, where summaries and tasks link back to transcript
  moments.

### Plaud

Observed mechanics:

- hardware recording transfers into the app after connection;
- transcript must finish before summary and mind map generation;
- automatic generation can choose template, AI model, and language;
- custom generation lets the user choose template, model, and language.

Takeaway for SuperDictate:

- model, language, and template selection must be visible at generation time;
- auto mode is useful, but the user needs an obvious "regenerate with different
  settings" path.

### Limitless

Observed mechanics:

- pendant recordings sync to iOS first, then web/Mac/Windows;
- desktop and mobile features do not have full parity;
- Lifelog view groups recordings by day;
- transcript edit, speaker edit, search, share, delete, and some Ask flows are
  mobile-first or mobile-only;
- export can be limited by surface.

Takeaway for SuperDictate:

- avoid platform gaps that make users switch devices for core review work;
- day-based memory is valuable, but project/client/person filters must sit next
  to it;
- export and delete must be reliable on desktop, mobile, and web.

### Granola

Observed mechanics:

- generated notes combine transcript, raw user notes, and calendar context;
- users can inspect where enhanced notes came from;
- generated notes can be edited, regenerated, and controlled through templates;
- calendar context is part of the quality loop, not just an integration.

Takeaway for SuperDictate:

- let users write raw notes during recording;
- generated claims need evidence links back to transcript, raw notes, or calendar;
- calendar should improve context before the meeting and close actions after it.

### Wispr Flow

Observed mechanics:

- dictation works anywhere the user can type;
- hotkey-first capture;
- AI commands rewrite, summarize, and adjust text;
- vocabulary learning, snippets, and style controls are first-class.

Takeaway for SuperDictate:

- keep short dictation as a separate "speak anywhere" surface;
- long-form meeting memory and quick dictation share local models, vocabulary,
  correction history, and style preferences;
- model choice should not turn the main capture flow into a configuration panel.

### Read-it-later products

Mozilla Pocket, Readwise Reader, Instapaper, Matter, Raindrop, and wallabag are
not the primary product category, but their archive patterns are useful:

- queue, inbox, archive, favorites, tags, folders, saved searches;
- offline availability;
- full-text and semantic search;
- highlights and annotations;
- export and import;
- browser and mobile share capture.

SuperDictate should use those patterns for recordings, transcripts, summaries,
and external evidence files.

## Product mechanics

### 1. Capture

The capture flow must be one action from every platform:

- Mac: menu bar record, global shortcut, floating meeting overlay, dock/menu
  command, and main window record button;
- Windows: tray record, global shortcut, overlay, and main window record button;
- iPhone: Action Button, Lock Screen widget, Control Center, Share Sheet import,
  Shortcuts, and in-app capture;
- Android: Quick Settings tile, launcher shortcut, Share Sheet import, widget,
  automation intent, and in-app capture;
- watchOS and Wear OS: complication/tile, one-tap start, marker, pause, stop,
  haptic confirmation, offline queue;
- web: upload/import/review, not primary live capture unless browser permission
  is available and reliable.

Capture must always expose:

- active mode/lens;
- elapsed time;
- pause/resume;
- marker;
- stop;
- input health;
- local save state;
- storage pressure;
- privacy/consent state.

### 2. Lenses and templates

Lenses are the user's intent before recording. Templates are the processing
instructions after recording. A lens can point to a default template, model,
language, and output workflow.

Default lenses:

- Quick Thought;
- Dictation;
- Meeting;
- Interview;
- Lecture;
- Client Call;
- Therapy / Coaching Session;
- Sales Discovery;
- Product Review;
- Daily Memory;
- Custom.

Every lens should define:

- expected duration;
- default transcription model;
- default summary model;
- language mode;
- speaker diarization expectation;
- summary sections;
- task extraction behavior;
- calendar behavior;
- export preset;
- retention preset.

### 3. Processing pipeline

Processing is a human-readable state machine:

```text
Saved locally
Finalizing audio
Queued
Transcribing
Detecting speakers
Structuring transcript
Summarizing
Extracting tasks
Building memory index
Ready
Needs recovery
```

Technical details such as chunk checksums, file sizes, manifests, and retry logs
belong in disclosure views and diagnostics, not the primary surface.

### 4. Review

The review surface has three synchronized tracks:

- Transcript: speaker segments, timestamps, search hits, audio scrubber, raw
  notes, and corrections.
- AI Review: summary, decisions, risks, unresolved questions, quotes, and mind
  map.
- Execution: tasks, owners, due dates, calendar slots, exports, follow-up drafts,
  integrations, and share links.

Every generated point should be evidence-backed with a transcript moment or raw
note reference. If the model infers a point, the UI must label it as inferred.

### 5. Execution

Tasks are not just bullets. A task item should carry:

- title;
- owner;
- due date or "not stated";
- confidence;
- evidence link;
- source recording;
- status;
- calendar action;
- export/share action.

The product should push toward a closed loop:

```text
Task found -> user verifies -> schedule or assign -> synced/exported
```

Calendar is not optional polish. It is a core product surface for meetings,
follow-ups, daily memory, and reminders.

### 6. Ask and memory

Ask must support explicit scopes:

- this recording;
- selected recordings;
- today;
- this meeting series;
- this person;
- this project/client;
- all local history;
- uploaded files plus recordings.

Good Ask answers include:

- short answer first;
- cited recording moments;
- confidence or missing-data notes;
- follow-up actions;
- saved query option;
- model choice for speed vs quality.

### 7. People and speakers

Speaker identity becomes a memory primitive:

- detect speakers per recording;
- name an unknown speaker;
- rename globally;
- merge duplicates;
- show all recordings for a person;
- separate transcript speaker identity from contact identity until the user
  confirms;
- allow deleting a speaker profile without deleting recordings.

### 8. Search and library

The library should support both timeline and knowledge-base behavior:

- Today;
- Inbox / needs review;
- Recents;
- People;
- Projects;
- Meetings;
- Tasks;
- Decisions;
- Risks;
- Favorites;
- Tags;
- Saved searches;
- Archive;
- Recovery.

Search must blend:

- exact transcript search;
- semantic search;
- speaker filters;
- date filters;
- project/client filters;
- task/decision/risk filters;
- source type filters;
- local-only/cloud-available filters.

## Design principles

### Native first

The app should feel like it belongs on each platform:

- Mac: sidebar, toolbar, inspector, menu bar, keyboard shortcuts, Spotlight-like
  command/search, system typography, sheets, native settings, drag-and-drop;
- iOS: tab bar, sheets, Live Activity, Lock Screen controls, swipe actions,
  Share Sheet, Shortcuts, large touch targets;
- Android: Material 3 navigation, foreground recording notification, quick tile,
  share intents, predictable back behavior;
- watch: glanceable state, haptic confirmations, no heavy review UI;
- web: dense library, review, admin, team, integrations, export.

Do not force one visual language everywhere. Keep product logic shared, but let
platform UI stay native.

### One action to record

The first screen must never be a marketing page or a JSON dashboard. It must let
the user record immediately, see what mode/model is active, and understand where
the result will go.

### Evidence over magic

Generated summaries, tasks, risks, decisions, and answers must reveal why they
exist. The UI should make it cheap to jump from a generated claim to the exact
audio/transcript moment.

### Local-first trust

The user should always know:

- whether audio is saved locally;
- whether processing is local or cloud;
- which model is active;
- whether files are encrypted;
- whether upload/sync is pending;
- whether deletion removes audio, transcript, AI outputs, or all of them.

### Beautiful means clear under pressure

The recording UI is used during meetings, calls, commuting, and thinking aloud.
It needs calm hierarchy, high contrast state, large primary controls, and no
decorative clutter. The review UI can be denser, but it must preserve reading
comfort and keyboard efficiency.

## Interaction blueprint

### First launch

1. Explain local-first storage and microphone permission.
2. Pick default model recommendation:
   - Intel Mac test default: `whisper.cpp` with `ggml-medium.bin` if storage and
     speed are acceptable, otherwise `ggml-small.bin`;
   - Apple Silicon default: WhisperKit medium or large-v3-turbo class model when
     available;
   - mobile default: platform-supported small/medium local model or queued
     processing when local runtime is unavailable.
3. Pick language mode: Auto, Russian, English, or multilingual.
4. Pick default lens.
5. Set global shortcut.
6. Start first recording.

### Main workbench

The primary layout:

- left sidebar: Today, Capture, Library, Tasks, Ask, People, Models, Settings;
- center: selected recording or capture surface;
- right inspector: model, processing, evidence, exports, recovery;
- top toolbar: record/stop, lens, model, search, export, share.

The home state should show:

- "Start recording" primary action;
- today's active queue;
- recordings needing review;
- tasks needing calendar time;
- installed model and privacy mode.

### Recording state

During recording:

- large elapsed timer;
- waveform/input health;
- active lens;
- active model;
- local save indicator;
- marker button;
- pause;
- stop;
- quick spoken-label hints in a non-intrusive place;
- meeting/calendar context if known.

### Post-recording state

After stop:

- show saved locally immediately;
- continue processing asynchronously;
- make transcript available as soon as partial text exists;
- update AI sections incrementally;
- keep recovery visible but not scary unless action is required.

### Review state

Review should support:

- audio playback synchronized with transcript;
- editable transcript segments;
- speaker rename/merge;
- raw notes alongside transcript;
- summary cards with source links;
- mind map with transcript backlinks;
- task checklist with calendar scheduling;
- "Ask this recording";
- export/share.

## Roadmap implications

### Next UI PRs

- Replace technical-first panels with Today, Capture, Library, AI Review, Tasks,
  Ask, Models, and Settings.
- Make every visible feature either interactive or clearly marked as runtime
  preview.
- Add lens selector, model selector, processing state rail, evidence links, task
  cards, calendar queue, mind map preview, and Ask scope chips to the web
  preview.
- Keep Mac-native layout patterns in the SwiftUI shell: sidebar, toolbar,
  inspector, sheets, command palette, menu bar.

### Runtime PRs

- finish crash-safe chunk writer and recovery journal;
- add local recording manifests and segment metadata;
- integrate Intel-friendly `whisper.cpp` path first;
- add model manager with install/download/checksum/runtime capability;
- implement transcription job queue;
- add summary/task extraction schemas;
- add embeddings/search index;
- add export pipeline;
- add calendar/task integration behind explicit permissions.

### Platform PRs

- add iOS capture app shell;
- add watchOS capture companion;
- add Android/Wear OS architecture notes and contracts before implementation;
- make web the durable review/admin/library surface;
- define sync protocol and conflict rules across devices.

## Source map

- Pocket Docs: https://docs.heypocketai.com/docs
- Pocket Day 1 guide: https://docs.heypocketai.com/docs/getting-started/day-1
- Pocket syncing methods:
  https://docs.heypocketai.com/docs/features/device/syncing
- Pocket recording summaries:
  https://docs.heypocketai.com/docs/features/productivity/summary
- Pocket action items:
  https://docs.heypocketai.com/docs/features/productivity/tasklist
- Pocket calendar hub:
  https://docs.heypocketai.com/docs/features/productivity/calendar
- Pocket Ask:
  https://docs.heypocketai.com/docs/features/ai/ask-pocket
- Pocket mind maps:
  https://docs.heypocketai.com/docs/features/organization/mind-maps
- Pocket speaker management:
  https://docs.heypocketai.com/docs/features/ai/speaker-management
- Pocket custom templates:
  https://docs.heypocketai.com/docs/features/productivity/templates
- Pocket changelog:
  https://feedback.heypocket.com/announcements
- Plaud summary and mind map:
  https://support.plaud.ai/hc/en-us/articles/55624401842841-How-to-Generate-a-Summary-and-Mindmap
- Limitless pendant interaction:
  https://help.limitless.ai/en/articles/10546658-interacting-with-the-pendant-search-ask-ai-summaries
- Granola AI-enhanced notes:
  https://docs.granola.ai/help-center/taking-notes/ai-enhanced-notes
- Wispr Flow:
  https://docs.wisprflow.ai/articles/2772472373-what-is-flow
- Mozilla Pocket shutdown:
  https://support.mozilla.org/en-US/kb/future-of-pocket
