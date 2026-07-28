# Trust, Privacy and Security Model

Status: product security foundation  
Scope: all clients, backend, processing workers and integrations

## 1. Trust position

SuperDictate handles conversations, private thoughts, client information and organizational decisions. Trust is not a settings page; it is a product capability.

The system follows these defaults:

- capture is local-first;
- recording is visibly indicated;
- cloud processing is explicit and configurable;
- long-term memory is narrower than raw storage;
- sensitive information is not promoted into memory silently;
- source and derived data are distinguishable;
- retention is understandable;
- export and deletion are first-class operations;
- private customer data is not used to train general models by default.

## 2. Data classes

Data is classified before storage and processing.

### 2.1 Account data

Examples:

- identity;
- authentication credentials and tokens;
- billing status;
- device registrations;
- workspace membership.

### 2.2 Source content

Examples:

- raw audio;
- audio chunks;
- uploaded media;
- original metadata and markers.

### 2.3 Derived content

Examples:

- transcripts;
- speaker segments;
- summaries;
- decisions;
- tasks;
- memory candidates;
- embeddings;
- generated drafts.

### 2.4 Configuration data

Examples:

- glossary;
- templates;
- retention settings;
- processing recipe;
- notification preferences;
- integration mappings.

### 2.5 Operational data

Examples:

- upload state;
- processing logs;
- audit events;
- performance metrics;
- error diagnostics;
- usage counters.

Operational data must avoid raw transcript or audio content unless explicitly required for a controlled support workflow.

## 3. Sensitivity levels

Initial levels:

- `standard` — ordinary work content;
- `confidential` — client or internal business information;
- `restricted` — highly sensitive content requiring limited processing and access;
- `private` — personal content visible only to its owner unless explicitly shared.

Sensitivity controls:

- eligible processors;
- storage region;
- memory extraction;
- external integrations;
- notification previews;
- retention;
- workspace visibility;
- support access.

## 4. Consent model

Consent policy is attached to capture mode and workspace policy.

Supported requirements:

- solo note, no participant consent workflow;
- reminder to inform participants;
- required confirmation that participants were informed;
- audible announcement where configured and supported;
- recording prohibited by policy.

The system stores consent status as session metadata, not as a legal guarantee.

The product must:

- make active recording visible;
- avoid stealth-recording affordances;
- provide localized reminders;
- let organizations enforce stricter rules;
- retain an audit event for policy acknowledgements where appropriate.

The product must not claim that a button press alone makes recording lawful in every jurisdiction.

## 5. Local-first capture

Before upload, every recording is stored in a crash-recoverable local format.

Requirements:

- platform data protection or encrypted application storage;
- atomic or chunked writes;
- recoverable metadata journal;
- bounded loss on crash;
- local queue state;
- checksum per completed chunk or object;
- deletion only after policy conditions are met;
- no dependency on an active session token to finish local capture.

## 6. Transport security

All network communication uses modern TLS.

Uploads use short-lived signed or scoped credentials.

Requirements:

- direct upload credentials are limited to one object or upload session;
- client cannot choose arbitrary workspace storage paths;
- credentials expire quickly;
- server validates size, type and checksum;
- completion endpoint is idempotent;
- replayed completion requests do not duplicate processing;
- webhook and worker callbacks are authenticated;
- integration tokens are encrypted and scoped.

## 7. Encryption at rest

Server-side storage uses encryption at rest.

Additional application-level encryption may be applied to restricted content.

Key principles:

- separate production secrets from source control;
- rotate service credentials;
- use managed secret storage;
- minimize services with decryption access;
- log key-management events without logging plaintext;
- support revocation of device credentials;
- separate customer content from analytics pipelines.

End-to-end encryption is a distinct product mode because server-side transcription and semantic search require plaintext processing somewhere. The UI must not misuse the term “end-to-end encrypted” when server processing can access content.

## 8. Processing trust boundary

A processing job receives only the minimum data required for its stage.

Examples:

- transcription worker receives audio and language hints;
- structuring worker receives transcript and requested recipe;
- embedding worker receives approved or policy-eligible text;
- integration worker receives only the action payload being synchronized.

Workers use short-lived access and do not have broad workspace browsing permissions.

Temporary worker files are deleted after job completion or bounded failure retention.

## 9. Provider policy

External model and infrastructure providers are adapters behind a policy layer.

For each provider, track:

- data region;
- retention behavior;
- training policy;
- subprocessor status;
- supported sensitivity levels;
- contractual status;
- model identifiers;
- incident contact and disable switch.

Restricted recordings may be limited to local processing or approved providers.

## 10. Retention model

Retention applies separately to:

- source audio;
- transcript;
- derived artifacts;
- memory;
- audit log;
- temporary processing data;
- backups.

Initial policies:

- delete source audio after successful processing;
- retain source audio for a fixed number of days;
- keep until user deletion;
- local-only source;
- workspace-admin managed retention.

Deleting audio does not automatically delete a transcript unless policy says so. The UI must show this distinction clearly.

Retention timers begin from a defined event such as capture, upload or successful processing. The chosen event is stored with the policy version.

## 11. Deletion semantics

Deletion states:

1. deletion requested;
2. hidden from active product views;
3. processing and indexing blocked;
4. primary data deleted;
5. derived indexes deleted;
6. integration consequences handled;
7. backup expiration pending;
8. deletion completed.

Requirements:

- user receives accurate status;
- retries are idempotent;
- deleted content is removed from retrieval immediately;
- deletion propagates to embeddings and caches;
- external systems are not silently modified unless configured;
- legal hold or organizational retention is visible to authorized users;
- support cannot casually restore deleted content.

## 12. Data export and portability

Users can export:

- source recordings where retained;
- transcript revisions;
- markers;
- insights and evidence;
- approved memories;
- projects and metadata;
- generated outputs;
- action synchronization history;
- settings and glossary.

Exports use documented formats such as JSON, Markdown, plain text and original audio.

A user should not need an active paid subscription to export or delete their data.

## 13. Access control

Initial workspace roles:

- owner;
- administrator;
- member;
- reviewer;
- guest.

Permissions are object-aware.

Examples:

- a guest may access selected project recordings only;
- a reviewer may confirm insights without managing billing;
- a private daily memory is not visible to workspace administrators unless explicitly moved into a shared scope;
- integration credentials are not exposed to ordinary members.

Authorization is enforced server-side. Client-side hidden controls are not a security boundary.

## 14. Sharing

Sharing is explicit and scoped.

Possible share types:

- generated summary only;
- transcript without audio;
- selected clips;
- full recording;
- project access;
- expiring public link.

Share links support:

- expiration;
- revocation;
- optional passcode;
- download control;
- access logging where lawful;
- privacy-safe preview metadata.

Private content is never made public through a default toggle.

## 15. Notification privacy

Default notifications avoid sensitive content.

Safe default:

- “Recording ready.”

Optional richer preview:

- title;
- artifact counts;
- action summary.

Transcript excerpts, participant names and private project names require explicit preview settings.

## 16. Logging and observability

Logs should contain identifiers and states, not customer content.

Do log:

- recording identifier;
- workspace identifier where necessary;
- stage and duration;
- byte counts;
- model and recipe version;
- error codes;
- retry count;
- region;
- deletion state.

Do not log by default:

- raw transcript;
- audio bytes;
- generated summary;
- participant names;
- authorization tokens;
- signed upload URLs;
- memory text.

Controlled debug access must be time-limited, authorized and audited.

## 17. Audit log

Shared workspaces maintain an audit log for material events:

- recording created;
- sharing changed;
- transcript corrected;
- memory approved or revoked;
- retention policy changed;
- export requested;
- deletion requested and completed;
- member access changed;
- integration connected or used;
- restricted processing override.

Audit logs record actor, action, object, timestamp and policy context without duplicating full content.

## 18. Analytics privacy

Product analytics are minimized and separated from content.

Allowed examples:

- capture started;
- capture finalized;
- transfer completed;
- processing stage latency;
- artifact reviewed;
- export used;
- retry invoked;
- mode selected.

Analytics must not include transcript text or raw titles.

Workspace owners can receive aggregate usage without access to private personal content.

## 19. Account and device security

Requirements:

- platform-native secure credential storage;
- device registration and revocation;
- session expiration;
- rate limits;
- suspicious-login protections;
- optional multi-factor authentication;
- secure account recovery;
- biometric gate for sensitive local views where available;
- remote sign-out;
- no secrets embedded in public client binaries beyond non-secret identifiers.

## 20. Integration security

Integration connectors use least privilege.

Requirements:

- explain requested scopes before authorization;
- store refresh tokens encrypted;
- isolate credentials by workspace and user;
- support revocation;
- show last synchronization;
- preview high-impact writes;
- protect against duplicate writes;
- validate inbound webhook signatures;
- avoid sending source audio when text is sufficient.

## 21. Abuse prevention

Controls include:

- upload size and duration limits;
- rate limits;
- workspace quotas;
- malware and malformed-media validation;
- content-type verification;
- signed URL restrictions;
- processing concurrency limits;
- anomaly detection for account takeover and automated abuse;
- administrative disable switch for compromised integrations or providers.

Abuse controls must not cause silent loss of an already captured local recording.

## 22. Threat model priorities

Initial high-priority threats:

- unauthorized access to recordings;
- leaked signed upload URLs;
- cross-workspace object access;
- compromised device or token;
- overly broad worker credentials;
- content leakage through logs;
- stale embeddings after deletion;
- malicious media files;
- integration writes to the wrong account;
- hidden recording misuse;
- model provider policy drift;
- accidental sharing through notification previews.

Each production feature includes a privacy and threat-model review.

## 23. Incident behavior

The service needs documented procedures for:

- credential leak;
- provider breach;
- cross-tenant exposure;
- failed deletion propagation;
- corrupted recordings;
- unauthorized integration writes;
- model output incident;
- regional outage.

The product must be able to disable upload, processing, sharing or one provider independently without disabling local capture.

## 24. Trust acceptance criteria

A release is not production-ready unless:

- capture state is visible;
- local artifacts survive expected failures;
- access control is server-enforced;
- private content does not enter logs;
- deletion removes retrieval access immediately;
- storage and processing retention are documented;
- model-provider use is policy-controlled;
- user export works;
- integration writes are attributable and idempotent;
- no hidden recording path exists;
- sensitive notification previews are opt-in;
- source and generated content are visually distinct.