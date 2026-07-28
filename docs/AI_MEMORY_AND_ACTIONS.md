# AI, Memory and Actions Specification

Status: product and domain specification  
Scope: processing pipeline, derived knowledge, retrieval and actions

## 1. Principle

SuperDictate may summarize, classify and connect information, but it must not hide the distinction between:

- what was said;
- what the system inferred;
- what the user approved;
- what was sent to another system.

The product must be useful without pretending certainty.

## 2. Processing pipeline

Each processing run is versioned and produces explicit artifacts.

Recommended pipeline:

1. validate source integrity;
2. normalize audio without replacing the original;
3. detect speech regions;
4. transcribe with timing;
5. identify language changes;
6. separate speakers where supported;
7. apply project glossary and known-name corrections;
8. build topic chapters;
9. extract structured insight candidates;
10. attach evidence spans;
11. calculate confidence and ambiguity flags;
12. generate requested presentation artifacts;
13. create memory candidates only when policy permits;
14. wait for user approval where required;
15. synchronize approved actions and memories.

A failed optional stage must not invalidate a successful transcript. Processing stages expose partial success.

## 3. Transcript layers

The product maintains distinct layers:

### 3.1 Machine transcript

The direct timed output of the transcription engine.

### 3.2 Corrected transcript

User edits, glossary substitutions and approved speaker corrections.

### 3.3 Clean reading transcript

A derived presentation form that may remove filler words and repair punctuation without changing meaning.

### 3.4 Generated text

Summaries, briefs, messages and other synthesized output.

The UI must not present generated text as a verbatim transcript.

## 4. Evidence model

Every extracted insight includes one or more evidence spans.

An evidence span contains:

- recording identifier;
- transcript revision identifier;
- start and end offsets;
- speaker identifier when available;
- short excerpt;
- transcription confidence when available.

Evidence requirements:

- decisions require direct supporting language or an explicit user confirmation;
- action items require an expressed task or a user-created task;
- owners and deadlines require explicit evidence;
- a synthesis across several spans links all relevant spans;
- unsupported output is labeled as a suggestion, not an extracted fact.

## 5. Insight classes

### 5.1 Decision

A choice that participants treated as settled.

Fields:

- normalized statement;
- status: candidate, confirmed, superseded or revoked;
- decision maker when explicit;
- effective date when explicit;
- evidence;
- related alternatives;
- superseded decision reference.

The system must distinguish “we should” from “we decided.”

### 5.2 Action item

A concrete next step.

Fields:

- title;
- details;
- owner when explicit;
- due date when explicit;
- priority only when stated or assigned by user;
- evidence;
- destination integration;
- synchronization state;
- completion state.

The system may suggest an owner or date in a separate suggestion field, never in the extracted value.

### 5.3 Commitment

A promise made by a participant.

Commitments remain distinct from generic tasks because they are useful for accountability and follow-up.

### 5.4 Open question

A question left unresolved or explicitly deferred.

Fields include:

- question;
- asker when known;
- responsible respondent when assigned;
- due date when stated;
- related decision or action;
- evidence.

### 5.5 Risk or blocker

A stated condition that may prevent progress.

The system separates direct statements from inferred risks.

### 5.6 Client correction

A requested modification to an existing artifact.

Fields:

- target artifact;
- location or component;
- requested change;
- rationale;
- status;
- priority when stated;
- ambiguity flag;
- contradiction links;
- evidence.

### 5.7 Fact candidate

A potentially reusable statement about a project, person, preference or constraint.

A fact candidate is not automatically a memory.

## 6. Confidence and ambiguity

Confidence is not a decorative percentage.

The system should expose meaningful categories:

- high: clear direct evidence and reliable transcript;
- medium: likely interpretation with minor ambiguity;
- low: unclear wording, speaker uncertainty or inferred relationship;
- user-confirmed: explicitly approved by a user;
- contradicted: conflicts with another active statement;
- stale: validity may have expired.

Low-confidence results are grouped for review rather than mixed into confirmed output.

## 7. Memory model

Memory is deliberate, scoped and attributable.

### 7.1 Memory scopes

- `recording`: usable only inside one recording;
- `project`: usable across a project;
- `workspace`: usable across shared workspace contexts;
- `personal`: usable only by one user across their private contexts;
- `disabled`: no persistent memory extraction.

### 7.2 Memory lifecycle

1. extraction creates a candidate;
2. policy determines whether review is required;
3. user or authorized workflow approves it;
4. memory becomes active;
5. later evidence can update, supersede or contradict it;
6. expiration or deletion removes it from retrieval;
7. audit history remains according to policy.

### 7.3 Memory fields

- normalized statement;
- scope;
- subject entities;
- sensitivity;
- provenance;
- confidence;
- review state;
- created and approved timestamps;
- valid-from and valid-until timestamps;
- supersedes and superseded-by relationships;
- access policy;
- embedding/index version;
- deletion state.

### 7.4 Memory categories

Initial categories:

- project constraint;
- approved decision;
- terminology;
- person preference;
- brand rule;
- recurring process;
- organization fact;
- active commitment;
- personal preference;
- custom.

Sensitive categories require explicit approval and may be prohibited by workspace policy.

## 8. Contradiction and supersession

The system does not silently choose between conflicting statements.

When a candidate conflicts with active memory:

- show both statements;
- show source dates and evidence;
- suggest likely supersession only when chronology and language support it;
- require confirmation for important project constraints;
- preserve the old statement as superseded rather than deleting history.

Example:

- Earlier: “The launch date is 10 September.”
- Later: “We moved the launch to 24 September.”

The second may supersede the first because the language explicitly indicates a change.

## 9. Ask SuperDictate

Question answering uses a structured retrieval process:

1. identify scope requested by the user;
2. retrieve approved memories;
3. retrieve relevant transcript spans;
4. distinguish current, superseded and candidate information;
5. generate an answer;
6. attach evidence links;
7. state uncertainty or missing information;
8. avoid using inaccessible workspace content.

Answer labels:

- **From source** — directly supported;
- **Synthesis** — combines multiple sources;
- **Inference** — reasonable but not explicit;
- **Unknown** — insufficient evidence.

The product must be willing to answer “I could not find evidence.”

## 10. Project brief

Each project may have a living brief generated from approved knowledge.

Sections may include:

- current objective;
- stakeholders;
- approved constraints;
- latest decisions;
- active actions;
- open questions;
- risks;
- terminology;
- recent changes;
- source coverage date.

The brief is a materialized view, not a separate source of truth. Every section links back to underlying memories and recordings.

## 11. Generated outputs

Initial output templates:

- meeting recap;
- client follow-up;
- implementation checklist;
- design correction list;
- project status update;
- interview summary;
- article or post draft;
- email draft;
- task export;
- decision log;
- daily reflection;
- weekly digest.

Generated outputs record:

- source recording identifiers;
- template and version;
- user instructions;
- model configuration;
- creation time;
- user edits;
- delivery state.

Sending is always a separate explicit action from generating.

## 12. Action synchronization

Supported action destinations may include calendar, task managers, project tools, email and messaging.

Synchronization rules:

- no external write without explicit authorization;
- preview before first write to an integration;
- idempotency key per action and destination;
- visible sync state;
- conflict handling when an external item changes;
- backlink to source evidence where destination permits;
- deletion in SuperDictate does not silently delete external work unless configured and confirmed.

## 13. Human review patterns

The product prioritizes review by risk, not by volume.

Review queues:

- unclear speakers;
- low-confidence decisions;
- tasks with ambiguous owner;
- possible contradictions;
- sensitive memory candidates;
- corrections with unclear target;
- external actions awaiting approval.

High-confidence low-risk artifacts may be accepted in bulk, subject to user policy.

## 14. Personalization

Personalization sources:

- user-created glossary;
- project terminology;
- approved people and organizations;
- correction history;
- preferred writing style;
- output templates;
- integration choices.

Personalization must not create hidden behavioral profiles unrelated to the product purpose.

## 15. Model independence

Domain objects must not expose one provider’s proprietary response shape.

The processing layer uses adapters so transcription, diarization, embeddings and language models can change without migrating core product semantics.

Every processing run stores enough metadata to reproduce or explain the result:

- provider;
- model;
- model version when available;
- parameters;
- prompt/template version;
- processing timestamp;
- source revision;
- glossary version.

## 16. Failure behavior

Possible partial outcomes:

- audio saved, transcript unavailable;
- transcript ready, diarization unavailable;
- transcript ready, extraction failed;
- summary ready, memory indexing delayed;
- action created locally, external synchronization failed.

The UI exposes the exact failed stage and retry target.

It must not collapse all failures into “Something went wrong.”

## 17. Evaluation

The product requires maintained evaluation sets for:

- Russian and English transcription;
- mixed-language speech;
- names and project terminology;
- speaker attribution;
- decisions versus suggestions;
- action owner and due-date extraction;
- client corrections;
- contradictions;
- evidence alignment;
- private-data redaction.

Metrics include precision, recall, evidence coverage, correction rate, user approval rate and harmful false-positive rate.

For decisions and commitments, false positives are more damaging than false negatives. Evaluation thresholds reflect this.

## 18. Initial implementation sequence

1. timed transcript and revisions;
2. evidence span object;
3. decisions, actions and questions;
4. user review and correction;
5. project-scoped memory candidates;
6. approved memory retrieval;
7. evidence-backed questions;
8. contradiction and supersession;
9. generated follow-ups;
10. external action synchronization.