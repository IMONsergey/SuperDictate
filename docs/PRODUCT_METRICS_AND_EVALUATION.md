# Product Metrics and Evaluation

Status: measurement foundation  
Scope: activation, retention, reliability, intelligence quality, trust and economics

## 1. Measurement principle

The product should optimize for useful, trusted outcomes rather than raw recording volume.

A user recording more audio is not necessarily success. Success occurs when captured speech is preserved, understood, reviewed and later used.

## 2. North-star metric

**Trusted useful recordings per weekly active user**

A recording is counted as trusted and useful when:

- local capture finalized successfully;
- requested processing completed or a valid local-only result exists;
- the user viewed, exported, searched, approved, shared or acted on the result;
- no unresolved source-integrity failure exists.

This metric is supported by guardrails for privacy, false positives, cost and reliability.

## 3. Activation

A newly activated user completes the full loop:

1. grants required permission;
2. captures a recording;
3. recording finalizes locally;
4. processing completes;
5. user opens the result;
6. user performs one value action.

Value actions include:

- copy or insert cleaned text;
- approve an extracted task or decision;
- assign a recording to a project;
- export or share;
- ask an evidence-backed question;
- retrieve the recording on another device.

Measure:

- permission completion rate;
- time to first capture;
- capture-to-result latency;
- first-result open rate;
- first value-action rate;
- seven-day return rate after activation.

## 4. Capture reliability

Core metrics:

- capture start success rate;
- local finalization success rate;
- recovered partial-recording rate;
- unrecoverable recording-loss rate;
- median and tail finalization time;
- interruption incidence;
- local queue age;
- upload completion rate;
- duplicate upload rate;
- checksum failure rate;
- device storage failure rate.

The unrecoverable recording-loss target should be treated as a critical reliability SLO, not an ordinary product metric.

## 5. Processing reliability

Measure per stage:

- queue wait time;
- processing duration;
- success rate;
- retry rate;
- permanent failure rate;
- partial-success rate;
- cost;
- provider and model version;
- source duration and language.

End-to-end latency is segmented by recording length and priority class.

## 6. Transcription quality

Maintain controlled evaluation sets across:

- Russian;
- English;
- mixed Russian/English;
- noisy rooms;
- wrist capture;
- phone-on-table capture;
- close-mic desktop dictation;
- names and domain terminology;
- multiple speakers;
- low-volume participants;
- interruptions.

Metrics:

- word error rate where reference transcripts exist;
- named-entity error rate;
- punctuation correction rate;
- user edit distance;
- speaker-attribution error;
- timestamp alignment error;
- language-detection error.

User corrections feed evaluation sets only under an explicit data policy.

## 7. Intelligence quality

Each artifact class has separate precision and recall targets.

### Decisions

Measure:

- precision of extracted decisions;
- missed confirmed decisions;
- evidence alignment;
- confusion between suggestion and decision;
- user rejection rate.

False-positive decisions are a severe error.

### Action items

Measure:

- task extraction precision and recall;
- owner accuracy;
- due-date accuracy;
- unsupported owner/date rate;
- approval rate;
- external synchronization correction rate.

### Client corrections

Measure:

- target identification;
- requested-change completeness;
- ambiguity detection;
- contradiction detection;
- implementation checklist acceptance.

### Memory

Measure:

- candidate approval rate;
- sensitive-candidate rejection rate;
- contradiction detection rate;
- stale-memory rate;
- source coverage;
- retrieval precision;
- answer citation click rate;
- unsupported-answer rate.

## 8. Trust metrics

Guardrails:

- recording indicator failure incidents;
- consent reminder completion rate where required;
- accidental recording discard rate;
- deletion completion latency;
- stale retrieval after deletion incidents;
- export success rate;
- unauthorized access incidents;
- content-in-logs incidents;
- sensitive notification exposure reports;
- share-link revocation latency;
- provider-policy violations.

Trust incidents are reviewed independently of engagement impact.

## 9. Cross-device metrics

Measure:

- watch-to-phone transfer success;
- median offline queue duration;
- state disagreement between devices;
- duplicate recording identifiers;
- handoff completion;
- result-open device;
- cross-device retrieval rate;
- device revocation propagation.

No client should maintain a private state model that cannot reconcile with the shared domain state.

## 10. Retention and usefulness

Measure behavior without reading content:

- recordings revisited after 1, 7, 30 and 90 days;
- project assignment rate;
- search success rate;
- evidence link open rate;
- approved-memory reuse;
- generated-output export rate;
- action completion where synchronized;
- user-created corrections;
- recordings deleted without viewing.

A high recording count combined with low revisit or action rate indicates a capture archive, not a useful product.

## 11. Product retention

Segment retention by primary job:

- desktop dictation;
- quick thoughts;
- meetings;
- client corrections;
- interviews;
- daily memory.

Measure:

- weekly active capture users;
- weekly active retrieval users;
- users performing both capture and retrieval;
- retained projects;
- recurring use of the same mode;
- device-pair retention for watch users.

## 12. Economics metrics

Measure:

- processed minutes per active user;
- cost per processed minute;
- gross margin by plan;
- storage cost by retention policy;
- premium-stage attach rate;
- reprocessing rate;
- top-up conversion;
- quota exhaustion timing;
- processing waste from failures;
- support cost per active user.

Cost metrics never include transcript text or sensitive metadata.

## 13. Event taxonomy

Events use stable names and versioned properties.

Core events:

- `capture_permission_requested`
- `capture_permission_resolved`
- `capture_started`
- `capture_marker_added`
- `capture_paused`
- `capture_resumed`
- `capture_finalized_local`
- `capture_recovered`
- `capture_discarded`
- `upload_queued`
- `upload_started`
- `upload_completed`
- `upload_failed`
- `processing_started`
- `processing_stage_completed`
- `processing_completed`
- `processing_failed`
- `result_opened`
- `insight_approved`
- `insight_rejected`
- `transcript_corrected`
- `memory_candidate_reviewed`
- `search_performed`
- `evidence_opened`
- `output_generated`
- `integration_write_confirmed`
- `export_completed`
- `deletion_requested`
- `deletion_completed`

Event properties include identifiers, state, timing, mode and version data. They do not contain transcript text, participant names or raw user titles.

## 14. Experiment guardrails

Experiments may change:

- onboarding order;
- mode defaults;
- review layout;
- output presentation;
- quota messaging;
- notification timing;
- upgrade presentation.

Experiments must not silently change:

- consent behavior;
- recording visibility;
- retention;
- deletion semantics;
- model-training policy;
- sharing scope;
- sensitive-memory defaults;
- external writes.

## 15. Release scorecard

Each release reports:

- capture loss and recovery;
- end-to-end processing reliability;
- median and p95 result latency;
- intelligence precision for high-risk artifact classes;
- deletion and export health;
- provider cost and gross-margin impact;
- new trust risks;
- unresolved incidents;
- platform parity deviations.

## 16. First vertical-slice success criteria

For Apple Watch quick thought:

- at least 95% of started test captures finalize locally under normal conditions;
- interruption and crash tests recover a usable artifact within the defined loss bound;
- duplicate upload rate is effectively zero under retry testing;
- most processed thoughts are opened on phone;
- users understand local, transferring, processing and ready states;
- task markers survive handoff;
- unsupported task or decision extraction remains below the release threshold;
- deletion removes the item from active retrieval immediately;
- battery impact remains within the agreed watch-session budget.

Production SLO values will be tightened after instrumented internal and beta testing.