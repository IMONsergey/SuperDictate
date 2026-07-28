# SuperDictate Product Operating System

Status: product foundation  
Owner: product / platform  
Scope: macOS, iOS, watchOS, Android, Wear OS and web

## 1. Product thesis

SuperDictate is not a recorder with an AI summary attached.

It is a personal and team operating system that turns spoken work into durable, attributable and actionable knowledge.

The core loop is:

1. **Capture** — start recording with minimal friction and without depending on a network connection.
2. **Understand** — produce a transcript and extract the structure of the conversation.
3. **Remember** — retain only useful, scoped and attributable knowledge.
4. **Act** — turn decisions and commitments into concrete outputs and integrations.
5. **Retrieve** — answer future questions using evidence from the original recordings.

Every feature must improve at least one part of this loop. Features that do not improve capture reliability, understanding quality, memory usefulness, action completion or trusted retrieval are secondary.

## 2. Product promise

The user should be able to leave a conversation and trust that:

- the recording was not lost;
- important moments are recoverable;
- decisions are separated from suggestions;
- commitments are assigned to the correct person where possible;
- uncertainty is visible rather than hidden;
- every extracted claim can be traced to evidence;
- private information is not silently promoted into long-term memory;
- the result is usable across all of the user's devices;
- the user remains in control of storage, retention and deletion.

## 3. Non-goals

SuperDictate must not become:

- an always-listening surveillance product;
- a hidden recording tool;
- a social network;
- a generic chat interface with an audio attachment;
- a source of invented decisions or false certainty;
- a mandatory cloud archive of every spoken word;
- a full project-management suite;
- a replacement for legal, medical or financial records;
- a product that requires constant connectivity to preserve audio.

## 4. Primary jobs to be done

The product is organized around situations rather than demographic personas.

### 4.1 Capture a thought before it disappears

The user needs to start recording in one gesture, speak naturally and continue the day without organizing the note immediately.

Expected result:

- concise title;
- cleaned transcript;
- core idea;
- optional tasks;
- links to related projects or prior thoughts.

### 4.2 Convert speech into polished text

The user dictates content intended for another application.

Expected result:

- faithful text;
- configurable cleanup level;
- preserved terminology and names;
- optional insertion into the active application;
- no unnecessary summary or memory extraction.

### 4.3 Leave a meeting with decisions and ownership

The user records a meeting and needs reliable follow-through.

Expected result:

- participants when identifiable;
- agenda and topic sections;
- decisions;
- action items with owners and due dates when explicitly stated;
- commitments;
- unresolved questions;
- risks and blockers;
- follow-up draft;
- evidence for every extracted item.

### 4.4 Capture client corrections without losing nuance

The user receives dense feedback and needs an implementation-ready change list.

Expected result:

- corrections grouped by page, screen, slide, asset or topic;
- exact requested change;
- rationale when stated;
- priority and approval status;
- contradictions and ambiguous comments;
- items requiring clarification;
- comparison against earlier decisions where available.

### 4.5 Build a durable interview record

The user conducts an interview and needs accurate attribution and later retrieval.

Expected result:

- speaker-separated transcript where confidence permits;
- topic index;
- notable quotes with evidence;
- claims and factual assertions;
- follow-up questions;
- explicit separation between interviewer interpretation and respondent statements.

### 4.6 Maintain a private daily memory

The user records a personal reflection, work log or daily review.

Expected result:

- private summary;
- themes and mood only when explicitly enabled;
- commitments to self;
- notable events;
- links to earlier entries;
- conservative memory extraction;
- strict privacy and retention controls.

## 5. Core domain model

### 5.1 Workspace

A security and billing boundary. A workspace may be personal or shared.

A workspace owns:

- members and roles;
- projects;
- recordings;
- processing policies;
- retention policies;
- integrations;
- audit events;
- usage and billing.

### 5.2 Project

A durable context boundary such as a client, product, presentation, research stream or personal area.

A project contains:

- recordings;
- approved memories;
- people and organizations;
- glossary and terminology;
- open decisions;
- action items;
- generated briefs;
- linked external systems.

### 5.3 Recording

The immutable source event created by a capture session.

A recording has:

- client-generated identifier;
- source device and platform;
- capture mode;
- timestamps;
- audio assets and chunks;
- markers;
- consent state;
- processing policy;
- retention policy;
- transcript versions;
- processing runs;
- derived outputs.

The original source and its integrity metadata must not be silently replaced by a processed version.

### 5.4 Transcript

A versioned interpretation of the source audio.

A transcript stores:

- language;
- segments and timing;
- speaker attribution;
- confidence data where available;
- user corrections;
- model and processing metadata;
- relationship to the source recording.

User edits create a new revision or an auditable correction layer; they do not erase the original machine output.

### 5.5 Insight

A structured claim extracted from a recording.

Supported insight classes include:

- decision;
- action item;
- commitment;
- open question;
- risk;
- correction;
- fact candidate;
- notable moment.

Every insight must contain provenance pointing to one or more transcript spans.

### 5.6 Memory

A reusable statement approved for retrieval beyond one recording.

A memory has:

- scope: recording, project, workspace or personal;
- provenance;
- sensitivity;
- confidence;
- review state;
- validity period or expiration;
- supersession relationship;
- access policy.

Raw extracted statements are memory candidates, not trusted memories.

### 5.7 Action

A concrete next step derived from an explicit statement or created by the user.

An action has:

- title;
- description;
- owner;
- due date when stated or manually added;
- source evidence;
- destination integration;
- sync state;
- completion state.

SuperDictate does not invent an owner or deadline. Missing values remain missing.

## 6. Capture modes

The initial product supports these modes:

| Mode | Primary output | Long-term memory default | Typical device |
|---|---|---|---|
| Quick thought | Idea, title, optional tasks | Personal, review required | Watch / phone |
| Dictation | Cleaned text | Disabled | Mac / phone |
| Meeting | Decisions, actions, questions | Project candidates | Phone / watch / desktop |
| Client corrections | Structured change list | Project candidates | Phone / watch / desktop |
| Interview | Attributed transcript and topics | Recording only by default | Phone / desktop |
| Daily memory | Private reflection | Personal, conservative | Watch / phone |
| Custom | User-selected recipe | User-selected | Any |

Modes define processing defaults, not hard limitations. A user can override retention, outputs and memory behavior before or after capture.

## 7. The universal recording lifecycle

All clients implement the same conceptual lifecycle:

1. `idle`
2. `preparing`
3. `recording`
4. `paused`
5. `finalizing`
6. `storedLocally`
7. `queuedForUpload`
8. `uploading`
9. `uploaded`
10. `queuedForProcessing`
11. `processing`
12. `ready`
13. `failedRecoverable`
14. `failedPermanent`
15. `deleted`

A device may display a simplified subset, but it must not invent incompatible state semantics.

Critical invariants:

- recording never depends on network availability;
- stopping a recording must create a recoverable local artifact before upload begins;
- deletion is explicit and auditable;
- retries are idempotent;
- the same client recording identifier survives retries and device handoff;
- UI never reports `ready` before the requested outputs exist;
- recoverable failures expose a retry path;
- permanent failures preserve the source unless the user deletes it.

## 8. Processing recipes

A recipe is a versioned set of requested artifacts and policies.

Initial artifacts:

- verbatim transcript;
- cleaned transcript;
- short summary;
- detailed summary;
- topic chapters;
- decisions;
- action items;
- commitments;
- open questions;
- risks and blockers;
- client corrections;
- key quotes;
- follow-up message;
- project brief update;
- memory candidates;
- custom structured output.

A recipe records:

- version;
- model configuration;
- language policy;
- glossary;
- sensitivity policy;
- memory scope;
- requested artifacts;
- output schema;
- user overrides.

Reprocessing creates a new processing run and never silently overwrites a prior result.

## 9. Platform roles

### watchOS and Wear OS

The watch is optimized for immediate capture and status, not document management.

Responsibilities:

- one-action capture;
- explicit recording indication;
- haptic confirmation;
- local queue;
- markers;
- mode selection with minimal friction;
- recent result status;
- handoff to phone.

### iOS and Android

The phone is the primary capture, review and organization surface.

Responsibilities:

- reliable local recording;
- background and resumable upload;
- transcript review;
- insight approval;
- project assignment;
- sharing and integrations;
- device queue management.

### macOS

The desktop is optimized for dictation, detailed review, editing and work-context insertion.

Responsibilities:

- global dictation;
- active-application insertion;
- meeting capture;
- project library;
- bulk review;
- export and integrations;
- local transcription where available.

### Web

The web client is optimized for library access, collaboration, administration and shared review.

It is not required for reliable capture.

## 10. Post-recording review model

The first review screen answers five questions:

1. What happened?
2. What was decided?
3. Who committed to what?
4. What remains unclear or blocked?
5. What should happen next?

The screen must separate:

- source transcript;
- model-generated interpretation;
- user-approved knowledge;
- external actions already synchronized.

Users must be able to correct an insight without editing the transcript and correct the transcript without silently approving an insight.

## 11. Retrieval model

Search supports three layers:

- lexical search over transcript and metadata;
- semantic retrieval over approved and candidate knowledge;
- evidence-backed question answering.

Every generated answer must distinguish:

- direct evidence;
- synthesis across sources;
- uncertain inference;
- missing information.

Answers should link to exact recording moments, not only to whole documents.

## 12. Product quality bar

### Capture reliability

- no recording loss during expected interruptions;
- crash-recoverable local artifacts;
- visible local/upload state;
- deterministic retry behavior;
- low-battery and storage warnings before failure where possible.

### Intelligence quality

- no invented owner, deadline or decision;
- evidence for extracted claims;
- confidence-aware speaker attribution;
- user correction path;
- versioned reprocessing;
- terminology support per project.

### Trust

- visible recording state;
- explicit consent workflow where configured;
- understandable retention choices;
- export and deletion controls;
- no model training on private data by default;
- auditability for shared workspaces.

### Cross-platform consistency

- same recording identifiers and domain states;
- same processing artifact semantics;
- platform-native interaction patterns;
- predictable handoff between devices;
- no platform-specific data silo.

## 13. Release principle

The product should ship as vertical slices that complete the full loop for one use case.

The first production slice is:

> Start a quick thought on Apple Watch, preserve it offline, synchronize through iPhone, transcribe it, show a concise result, optionally create tasks and retrieve it later with evidence.

A wide set of unfinished screens is not considered progress. A narrow, reliable loop is.