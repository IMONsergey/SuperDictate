# Packaging, Usage and Unit Economics

Status: commercial product foundation  
Scope: plans, quotas, cost controls and fair use

## 1. Commercial principle

SuperDictate sells reliable capture, trusted understanding and durable retrieval. It does not sell raw model calls.

Pricing and quotas must:

- remain understandable to ordinary users;
- protect the service from extreme usage;
- preserve useful free evaluation;
- keep recording available when cloud quota is exhausted;
- separate local capabilities from cloud processing costs;
- allow teams to budget predictable usage;
- avoid fake “unlimited” claims backed by hidden throttling.

## 2. Metering unit

The primary usage unit is a **processed audio minute**.

A processed minute is counted when source audio enters a transcription pipeline successfully.

Do not double-charge for:

- upload retries;
- infrastructure failures;
- reprocessing caused by a product defect;
- transcript viewing;
- search over already processed content;
- local-only dictation;
- deletion or export.

Possible additional metering dimensions:

- premium diarization minutes;
- retained source-audio storage;
- advanced generation runs;
- team seats;
- external integration volume;
- dedicated or restricted processing.

The product should not expose a confusing token-based billing model to end users.

## 3. Plan architecture

### 3.1 Local

For users who want private on-device or desktop transcription where supported.

Includes:

- local macOS dictation;
- local history;
- basic export;
- no required cloud account for core desktop dictation;
- optional paid upgrade for synchronization and advanced processing.

This preserves the existing local-first strength of SuperDictate.

### 3.2 Free

Purpose: prove the complete product loop, not merely show a demo screen.

Includes:

- limited monthly cloud minutes;
- quick thought and dictation modes;
- a small number of retained recordings;
- transcript and short summary;
- basic task extraction;
- cross-device synchronization;
- export and deletion.

Restrictions must be visible before capture when possible. The watch may always record locally, but cloud processing waits until quota becomes available or the user upgrades.

### 3.3 Individual

For consistent personal use.

Includes:

- larger monthly minute pool;
- all primary capture modes;
- project organization;
- detailed summaries;
- decisions, actions and questions;
- evidence-backed retrieval;
- configurable audio retention;
- personal memory;
- standard integrations.

### 3.4 Professional

For consultants, designers, founders and other users with frequent client work.

Includes:

- higher minute pool;
- client-correction recipes;
- advanced templates;
- enhanced speaker processing;
- project memory and living briefs;
- premium exports and integrations;
- longer source retention;
- priority processing during normal load;
- configurable glossary and terminology.

### 3.5 Team

For shared workspaces.

Includes:

- seat management;
- pooled or assigned minutes;
- project sharing;
- roles and permissions;
- audit log;
- workspace retention policy;
- shared glossary and templates;
- integration administration;
- private personal spaces inside the team account;
- usage reporting without exposing private content.

### 3.6 Enterprise or Dedicated

For organizations requiring stronger controls.

Potential capabilities:

- regional data residency;
- approved-provider restrictions;
- SSO and provisioning;
- custom retention;
- dedicated processing capacity;
- customer-managed storage or keys where feasible;
- contractual support;
- security review package;
- restricted or self-hosted transcription options.

This tier should not be built before real demand exists.

## 4. Quota behavior

When cloud minutes are exhausted:

- local capture continues;
- source remains on device;
- user sees that processing is waiting for quota;
- existing transcripts and memories remain accessible;
- export and deletion remain available;
- user may buy additional minutes or wait for renewal;
- the service never silently discards a captured recording.

Overage options:

- explicit top-up pack;
- automatic overage with user-configured monthly cap;
- team-admin approval;
- no overage.

Automatic billing must be opt-in and capped.

## 5. Processing priority

Priority may be used as a plan differentiator, but it must not make lower plans unreliable.

Suggested queues:

- interactive short notes;
- normal recordings;
- long meetings;
- bulk imports;
- reprocessing;
- low-priority background memory updates.

Priority affects waiting time, not output integrity.

## 6. Cost model

Track cost per recording across:

- ingress and storage;
- audio normalization;
- transcription;
- diarization;
- language-model structuring;
- embeddings and indexing;
- retrieval and generation;
- notifications;
- integration calls;
- support burden.

Required internal metrics:

- cost per processed minute;
- cost per active user;
- storage cost per retained hour;
- average artifacts generated per recording;
- reprocessing cost;
- provider cost by model and region;
- gross margin by plan;
- peak concurrency cost;
- failed-job waste.

## 7. Cost-control hierarchy

Optimize in this order:

1. avoid processing silence;
2. avoid duplicate jobs;
3. use appropriate model size by stage;
4. batch where latency permits;
5. cache derived results by source and recipe version;
6. delete temporary files;
7. tier expensive diarization and premium generation;
8. autoscale workers;
9. use local processing where it improves privacy or cost;
10. negotiate or self-host only after usage justifies operational complexity.

Cost reduction must not remove evidence, damage transcript quality silently or weaken privacy.

## 8. Fair-use and abuse controls

Required controls:

- maximum recording duration by plan or capture mode;
- maximum import size;
- monthly processed-minute quota;
- concurrent-job limit;
- retained-audio quota;
- API and upload rate limits;
- anomaly detection;
- workspace spending cap;
- manual review for extreme automated use.

Limits should be declared in product language. Hidden throttling is reserved for security incidents and acute service protection.

## 9. Storage packaging

Audio retention and transcript retention are separate.

Possible defaults:

- Free: short audio retention, transcript retained;
- Individual: configurable limited audio retention;
- Professional: longer audio retention;
- Team: administrator policy;
- local-only mode: source never uploaded.

Pinned recordings may consume a storage allowance. The UI shows what is consuming storage and provides bulk cleanup.

## 10. Reprocessing policy

Users can reprocess when:

- a better model becomes available;
- glossary changed;
- speaker names were corrected;
- recipe changed;
- language was detected incorrectly.

Billing rules:

- reprocessing after a service defect is free;
- user-requested premium reprocessing may consume credits or quota;
- UI shows cost impact before starting;
- previous result remains accessible until the new run succeeds.

## 11. Team minute allocation

Team options:

- pooled workspace minutes;
- per-member allowance;
- project budget;
- soft warnings;
- hard cap;
- administrator-approved overage.

Usage reports show duration and cost allocation without exposing transcript content to administrators who lack content access.

## 12. Trial and activation

The trial must allow a real result:

1. record from a supported device;
2. receive transcript and structured output;
3. review one evidence-backed task or decision;
4. retrieve the recording later;
5. export or share the result.

A trial that ends before the full loop does not prove value.

## 13. Upgrade moments

Acceptable upgrade moments:

- cloud minute pool exhausted;
- user enables advanced diarization;
- user wants longer source retention;
- user creates more projects;
- user enables team sharing;
- user connects premium integrations;
- user requests dedicated processing policy.

Unacceptable paywalls:

- deleting data;
- exporting personal data;
- recovering a locally captured recording;
- viewing a transcript already paid for;
- correcting an AI error;
- revoking a share link.

## 14. Subscription cancellation

After cancellation:

- local functionality remains where licensed or free;
- existing cloud library enters a clearly defined read/export period;
- deletion remains available;
- data is not immediately destroyed without warning;
- retention after the grace period follows published policy;
- shared workspace ownership transfer is handled before closure.

## 15. Commercial experiments

Run controlled experiments on:

- minutes included;
- retention value;
- individual versus professional differentiation;
- top-up preference;
- value of project memory;
- value of client-correction workflows;
- team pooled usage;
- local-only paid edition.

Do not experiment with hidden privacy defaults, destructive retention or misleading “unlimited” language.

## 16. Initial launch recommendation

Launch with a small number of plans:

- Local / desktop;
- Free cloud;
- Individual;
- Professional.

Delay Team until sharing, permissions and audit behavior are production-grade.

Delay Enterprise until there is a concrete customer requirement.

The first paid differentiator should be **reliable volume plus useful structured outputs**, not cosmetic themes or artificial feature fragmentation.