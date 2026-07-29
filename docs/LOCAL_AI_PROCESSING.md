# Local AI Processing

Status: runtime foundation  
Scope: offline transcription, summaries, action handlers and model boundaries

## Goal

SuperDictate must feel like a complete local-first dictation product, not a recorder shell. A finished local recording should immediately move into a visible processing flow:

1. verify the local chunk package;
2. transcribe locally;
3. show an editable timed transcript;
4. generate summaries and chapters;
5. extract decisions, tasks, risks and open questions;
6. require review before memory or external sync;
7. keep all source audio and generated artifacts private unless policy allows transfer.

The current foundation adds the shared contracts for that flow. Platform adapters can now plug in concrete engines without changing product semantics.

## Non-negotiable UX rules

- The transcript is never hidden behind a summary.
- Generated text is labeled and stored separately from verbatim transcript text.
- Every extracted decision, action, risk or question carries evidence spans.
- Failed optional processing does not destroy a valid transcript.
- Local model install state is explicit: not installed, downloading, ready, failed or disabled by policy.
- Cloud processing remains a user choice and is prohibited for local-only policies.

## Runtime responsibilities

`SuperDictateCore` owns:

- `LocalAIModelDescriptor` and `LocalAIModelCatalog`;
- `LocalAudioTranscribing`, `LocalTranscriptSummarizing` and `LocalInsightExtracting`;
- timed transcript and summary artifact models;
- local processing jobs, events, issues and results;
- `SuperDictateWorkbenchState` for native product tabs, metrics, commands and status badges;
- bundled rule-based summary and insight extraction fallback;
- conversion from action insights to local `ActionItem` objects.

Platform apps own:

- model downloads and license prompts;
- microphone permission UX;
- native SwiftUI/AppKit screens;
- model runtime binaries and sandbox entitlements;
- background scheduling;
- transcript editing and review interactions;
- persistence of processing results.

## Model strategy

The product should support free local engines first, while keeping model weights outside the repository.

| Need | Adapter family | Default stance |
| --- | --- | --- |
| Offline transcription | `whisper.cpp` | Good first cross-platform adapter; engine is MIT, model/checkpoint license is verified at install time. |
| Apple-native transcription | Argmax OSS / WhisperKit | Good Apple Silicon path; SDK is MIT with third-party notices and model license verification. |
| Local summaries and structured extraction | `llama.cpp` | Good runner boundary for GGUF instruct models; runner is MIT, selected model license varies. |
| Free local instruct model candidate | Qwen2.5 7B Instruct | Referenced model card is Apache 2.0; quantized distributions still require verification. |
| No model installed | Built-in rule-based handlers | Always available fallback for summaries, actions and review queues. |

Model records must include:

- adapter kind;
- capabilities;
- local install state;
- disk footprint;
- source URL;
- license summary;
- whether network download is required;
- user-visible notes.

## Processing pipeline

```text
finalized chunks
  -> durable package validation
  -> LocalAudioTranscribing
  -> LocalTranscript revision
  -> LocalTranscriptSummarizing
  -> LocalInsightExtracting
  -> local ActionItem candidates
  -> review queue
  -> optional sync/export
```

Required stage:

- transcription.

Partial-success stages:

- summaries;
- topic chapters;
- decisions;
- action items;
- commitments;
- open questions;
- risks;
- client corrections;
- memory candidates;
- follow-up drafts.

Partial-success failures become `LocalProcessingIssue` records and must be visible in the UI.

## Handler behavior

The bundled rule-based handlers are intentionally conservative. They are not a replacement for Whisper or an LLM, but they make the product useful and testable before the user installs a model:

- extractive summary bullets from transcript sentences;
- action detection for English and Russian task language;
- decision detection for explicit decision phrases;
- risk/open-question/client-correction candidates;
- local action item creation from action insights.

Neural adapters may improve quality, but they must preserve the same output contracts.

## Product screens

The next native UI stage should expose these first-class surfaces:

- Recorder: large timer, waveform, source level, chunks, markers and recovery status.
- Processing: model status, progress stages, issues and retry controls.
- Transcript: timed editable segments, speaker labels, confidence and source jump.
- Summary: short brief, detailed brief, chapters and key quotes.
- Actions: decisions, tasks, risks, questions and review state.
- Models: installed engines, download size, license, local-only toggle and privacy policy.

The UI should look dense and professional: command-center layout, strong hierarchy, no landing page, no decorative cards around every section, and clear status chips for local/private/needs-review/failed states.

`SuperDictateWorkbenchState` now provides the shared source of truth for this surface. Native views should render its `availableTabs`, `headlineMetrics`, `badges`, `primaryCommand`, `processingProgress` and `modelStates` rather than re-deriving state in each platform target.

## Next implementation steps

1. Add a native SwiftUI shell around recorder, processing, transcript, summary and actions.
2. Add a WhisperKit or whisper.cpp transcription adapter behind `LocalAudioTranscribing`.
3. Add a llama.cpp-compatible summarization/extraction adapter behind the existing protocols.
4. Persist `LocalProcessingResult` next to the recording package.
5. Wire model install state into the UI and recovery journal.
