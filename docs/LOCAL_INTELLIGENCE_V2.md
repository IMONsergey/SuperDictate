# Local intelligence v2

Status: backend-neutral production foundation.

## Product rule

SuperDictate UI and durable Library must not depend on a specific LLM runtime.

The Core contract owns:

- capability discovery;
- source evidence identity;
- grounded answer/summary/task result types;
- the rule that grounded generated content cannot exist without source citations.

Concrete inference backends stay behind `SuperDictateIntelligenceProvider`.

## Provider order

### Baseline portable provider — llama.cpp adapter

Best candidate for the first owned local synthesis adapter because it has a broad CPU backend in addition to Apple Silicon acceleration. This is the most compatible path with a future Intel Mac build.

Do not vendor `main` blindly. Pin a tested upstream revision and treat GGUF/model compatibility as part of the release matrix.

### Apple Silicon optimized provider — MLX Swift adapter

Useful later when benchmark data shows a material latency/memory advantage for supported Apple Silicon hardware. It should implement the same Core protocol, not introduce separate Summary/Ask product behavior.

Do not make MLX the only product path while Intel support remains a goal.

### System provider — Apple Foundation Models adapter

Treat as an optional modern-OS adapter, never the macOS 14 baseline. OS/model availability must be detected at runtime and failure must fall through to another installed local provider.

## Grounding pipeline

Ask:

1. scope query to allowed recording IDs;
2. retrieve exact local evidence segments;
3. construct a bounded context from those segments;
4. ask the selected provider to synthesize only from that context;
5. validate `SuperDictateMemoryAnswer`;
6. if provider output cannot be grounded, return `insufficientEvidence` rather than a model-only answer.

Summary:

1. read one durable `SuperDictateMemoryDocument`;
2. provider generates a small document-like section set;
3. every generated section must carry one or more exact evidence citations;
4. UI renders citations quietly as source links rather than large cards.

Tasks:

1. provider proposes an action statement;
2. each proposal carries evidence citations;
3. user accepts/edits/dismisses proposal;
4. only accepted tasks become durable `SuperDictateTask` rows;
5. calendar integration remains a separate explicit action.

## Privacy policy

The default product contract is local-first.

A future cloud provider must be opt-in and declare that it is non-local in its provider descriptor. The UI must never silently switch a local request to cloud because a model is unavailable.

## Model management

Models belong in Settings, not the main toolbar.

Future model manager responsibilities:

- installed model list;
- disk size;
- compatible provider/backend;
- hardware/OS compatibility;
- verified download state;
- remove/redownload;
- local/cloud policy.

Primary Dictation/Library/Ask views should normally not expose model names.

## Evaluation gate

A provider does not become default because it runs.

Benchmark on real SuperDictate workloads:

- Russian and English meeting summaries;
- task extraction precision/recall;
- answer citation faithfulness;
- time-to-first-token and total latency;
- peak resident memory;
- cold/warm model load;
- battery/thermal impact;
- Intel CPU fallback where supported;
- malformed/long transcript behavior.

Prefer the smallest provider/model combination that meets product quality rather than exposing model choice as a permanent product decision.
