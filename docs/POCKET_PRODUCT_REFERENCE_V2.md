# Pocket / HeyPocket product reference for SuperDictate

Status: active product reference, not a visual cloning specification.

Last source review: 2026-08-08.

## Purpose

Pocket / HeyPocket is useful to SuperDictate because it demonstrates how a technically broad conversation-memory product can present itself as a small number of simple user jobs.

SuperDictate should borrow the **reduction of complexity, product loops and interaction mechanics**, not Pocket's brand, hardware identity, visual styling, copy, icons or screen layouts.

The governing SuperDictate interface contract remains `DESIGN_SYSTEM_V2.md`.

## Current Pocket product model

The Pocket system can be reduced to this loop:

```text
Capture -> organize -> understand -> act -> retrieve
```

Its strength is not that every capability is visible. Its strength is that hardware/software context chooses much of the workflow and progressively reveals deeper tools around a recording.

### Capture intent / lenses

Pocket documents capture lenses such as:

- Meeting;
- Discovery Call;
- Interview;
- Journaling;
- Auto Detect.

The important principle is **intent before processing detail**. A user chooses the kind of conversation/work, not a graph of speech and language models.

#### SuperDictate implication

Long-form Memory Capture may eventually expose a small intent/lens control, but it must not become a model configuration screen.

Instant Dictation needs no lens at all in its normal path.

## Spoken structure

Pocket allows spoken labels such as:

- decision;
- action item;
- risk.

This is powerful because structure can be captured without interrupting the conversation to operate UI.

#### SuperDictate implication

Add optional voice markers only after the basic record/marker flow is stable. They should produce evidence-linked candidates, never silently authoritative objects.

Potential SuperDictate phrases can map to product concepts rather than raw prompt text:

- decision marker;
- task marker;
- risk marker;
- remember this;
- follow up.

The spoken marker remains attached to a source timestamp/audio span.

## Summary

Pocket turns a recording into a readable summary rather than forcing users through its internal processing graph.

Its documented processing may involve multiple stages, but those stages are secondary to the resulting note.

#### SuperDictate implication

The default recording detail should show a document-like Summary. Do not expose `validate -> transcribe -> diarize -> summarize -> extract -> index` as permanent navigation.

Only show a human processing state such as:

- Saving…
- Transcribing…
- Preparing summary…
- Ready
- Needs attention

Technical stages belong in diagnostics.

## Action items

Pocket treats action items as first-class objects and preserves a link to the source recording. This is one of the most important mechanics to copy conceptually.

#### SuperDictate implication

Every generated task must be able to answer:

- Where did this task come from?
- Was the owner actually stated?
- Was the due date actually stated?
- What exact transcript/audio evidence supports it?

A SuperDictate task should eventually carry:

```text
id
recording_id
title
status
source_span
owner?          // stated or user-confirmed only
due_at?         // stated or user-confirmed only
confidence?
calendar_link?
```

Do not invent owners or deadlines and present them as source truth.

## Calendar close-loop

Pocket's Day One guidance pushes important action items toward calendar time before the user leaves the workflow.

#### SuperDictate implication

Calendar is not a decorative integration. For verified tasks, the product should make `schedule` a cheap next action.

The flow should be:

```text
Task candidate -> verify -> schedule/assign/export -> done
```

Do not force calendar permissions during first dictation setup. Request them contextually when the user actually schedules something.

## Ask

Pocket supports Ask over memory with contextual suggestions and scoping/filtering by recordings and dates. Recent product updates also make model choice contextual to Ask rather than a permanent global product control.

#### SuperDictate implication

Ask should have explicit scope and evidence:

- this recording;
- selected recordings;
- today;
- person;
- project/client;
- all memory.

A good answer contains:

1. answer first;
2. compact source citations;
3. uncertainty/missing-data note when relevant;
4. optional follow-up action.

Do not ship a fake conversational shell before retrieval and citations are real.

Global model selection should not live in the main toolbar. Advanced model settings belong in Settings; a future Ask-specific quality/model choice is acceptable only when it directly changes the current answer workflow.

## Mind maps

Pocket can generate mind maps with a central theme, branches and nodes that navigate back toward relevant transcript material.

#### SuperDictate implication

A mind map can be useful for long interviews, lectures and complex meetings, but it is **not a primary destination**.

Treat it as an alternate visualization from Summary. Every node should have a source jump.

Do not ship it before Summary/Transcript source linking is robust.

## Speaker identity

Pocket supports naming speakers from a transcript, reusing identity, merging duplicates and opening recordings associated with a person.

#### SuperDictate implication

People should become an entity layer inside Library/search, not a fifth top-level destination.

Identity rules:

- detected speaker != contact until user confirms;
- renaming can apply locally to one recording or globally after confirmation;
- duplicate people can merge;
- deleting a person profile must not implicitly delete source recordings;
- every speaker identity operation must preserve transcript chronology.

## Templates

Pocket provides preset templates and custom sections/instructions.

#### SuperDictate implication

Templates are a processing preset behind a capture intent, not permanent primary navigation.

Possible future defaults:

- Meeting;
- Interview;
- Discovery;
- Lecture;
- Daily reflection;
- Custom.

A template may select summary structure and extraction behavior. It should not require the user to understand the underlying local/cloud model stack.

## Sync and recovery

Pocket documents multiple hardware sync routes and explicit retry behavior when a recording is not processed correctly.

SuperDictate does not have Pocket hardware and should not imitate those transport details.

The useful principle is **visible recoverability at the affected recording**, not a generic Recovery dashboard.

#### SuperDictate implication

When processing fails:

- keep local source safe;
- show the problem on the recording;
- expose `Try Again` / recovery action there;
- place detailed journal/checksum state behind Technical Details;
- never silently discard source audio because cloud/model processing failed.

## Desktop meeting behavior

Pocket's 2026 desktop work includes meeting detection, native meeting notifications, automatic recording behavior, meeting-end handling, participant context, desktop search/Ask and on-device transcription improvements.

These are highly relevant to SuperDictate's Mac Memory Capture direction.

#### SuperDictate implication

After Instant Dictation and the basic recording Library are stable, prioritize:

1. meeting detection;
2. contextual notification / one-click capture;
3. reliable stop/meeting-end behavior;
4. calendar context;
5. participant context where platform APIs allow it;
6. local live transcript;
7. post-meeting Summary/Tasks;
8. global search/Ask.

This is more valuable to the Mac product than prematurely building Android/Wear OS parity.

## Model abstraction

Pocket increasingly presents intelligence as a product capability rather than forcing users to manage every model globally.

#### SuperDictate implication

Our stronger local-first stance still needs a real model manager, but it belongs in Settings.

Default behavior:

- recommend/select a good model for the hardware;
- explain download size and privacy only when relevant;
- allow advanced users to override;
- expose a contextual quality choice only inside workflows that benefit from it;
- never put a model dropdown in every recording screen or the global toolbar.

## Search / command surface

Pocket's desktop evolution treats search and Ask as increasingly central retrieval surfaces.

#### SuperDictate implication

Long-term Mac command/search should unify:

- exact transcript search;
- semantic retrieval;
- people/project filters;
- commands;
- Ask.

But the default Library remains a readable native list. A command palette is a power-user acceleration layer, not the home screen.

## What SuperDictate should copy conceptually

- one-action capture;
- intent/lens rather than model configuration;
- readable summaries;
- source-linked action items;
- calendar close-loop;
- scoped Ask;
- speaker identity that improves over time;
- source-linked alternate views such as mind maps;
- contextual recovery;
- desktop meeting detection;
- context-aware automation;
- progressive disclosure of intelligence.

## What SuperDictate should explicitly not copy

- hardware dependency;
- Pocket branding, colors, iconography or screen composition;
- cloud-first assumptions;
- visual duplication of their cards, navigation or marketing language;
- a one-to-one feature race before core reliability is excellent;
- model/provider choices that ignore local privacy and device capability;
- hidden source provenance for generated claims.

## Where SuperDictate must be better

### 1. Instant Dictation

Pocket is conversation-memory-first. SuperDictate already has a strong speak-anywhere hotkey runtime. This should remain a major differentiator.

### 2. Local-first operation

Normal dictation and as much Memory Capture processing as practical should work locally without an account.

### 3. Ownership

Export, delete, corrections and local source access must remain first-class controls rather than premium hostage features.

### 4. Evidence

Generated summaries, tasks and answers should make source verification cheaper than competitors do.

### 5. Mac nativeness

The desktop experience should feel designed for macOS rather than a website inside a window:

- real menu commands;
- keyboard navigation;
- semantic system colors;
- native window/sidebar/settings behavior;
- contextual toolbar;
- Spotlight-like command/search only where useful;
- lightweight reading surfaces.

### 6. Graceful complexity

The system can eventually contain multiple ASR models, summarizers, embeddings, speaker models, sync paths and integrations while the default interface still exposes only a handful of concepts.

That is the central competitive design objective.

## SuperDictate product loop

The target loop becomes:

```text
Instant Dictation
Hotkey -> speech -> reliable text insertion

Memory Capture
Record -> source-safe local save -> transcript -> readable summary
       -> verify tasks/decisions -> calendar/export
       -> retrieve later through Library/Search/Ask
```

These two loops share one local trust foundation but do not need to share one dense screen.

## Design review questions derived from Pocket

For every SuperDictate feature PR ask:

1. Does this reduce or increase the number of concepts the default user must understand?
2. Could the system infer/select this safely instead of asking every time?
3. Is the control contextual, or are we adding it globally because implementation was easier?
4. Can generated output jump back to source evidence?
5. If processing fails, is recovery located at the affected object?
6. Does the user need to know the model/provider at this moment?
7. Does this improve the capture -> act -> retrieve loop?
8. Is this genuinely better for SuperDictate, or are we copying a competitor feature because it exists?

If the feature adds visible complexity without improving one of the core loops, do not ship it in primary UI.

## Primary source map

- Pocket documentation: `https://docs.heypocketai.com/docs`
- Day One guide: `https://docs.heypocketai.com/docs/getting-started/day-1`
- Recording / summary: `https://docs.heypocketai.com/docs/features/productivity/summary`
- Action items: `https://docs.heypocketai.com/docs/features/productivity/tasklist`
- Calendar: `https://docs.heypocketai.com/docs/features/productivity/calendar`
- Ask: `https://docs.heypocketai.com/docs/features/ai/ask-pocket`
- Mind maps: `https://docs.heypocketai.com/docs/features/organization/mind-maps`
- Speaker management: `https://docs.heypocketai.com/docs/features/ai/speaker-management`
- Templates: `https://docs.heypocketai.com/docs/features/productivity/templates`
- Device sync: `https://docs.heypocketai.com/docs/features/device/syncing`
- Product / current positioning: `https://heypocket.com/`
- Current announcements/changelog: `https://feedback.heypocket.com/announcements`

Source behavior changes over time. Re-review current Pocket documentation before making a major product decision that depends on competitor behavior.
