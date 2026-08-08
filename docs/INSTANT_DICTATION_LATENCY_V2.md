# Instant Dictation latency v2

Status: implementation plan pinned to the current FluidAudio revision `313feb4bd692780a9a5b5fa9048fdb119486dde8`.

## Constraint first

The production engine is Parakeet TDT v3 because SuperDictate needs multilingual dictation, including Russian. The pinned FluidAudio revision also exposes a true streaming EOU manager, but that is a separate English-only model path. Replacing the production Parakeet v3 engine with EOU just to obtain streaming would be a language/quality regression.

## Existing concurrency invariant

`TranscriptionWorker` is the owner of the loaded speech engine and already has an in-flight reentrancy backstop. Any latency optimization must remain behind that actor. The audio callback must never invoke shared CoreML inference concurrently with the release-time transcription path.

## Recommended hybrid

### Short dictations

Keep the existing batch path.

Why:
- minimal orchestration overhead;
- current model accuracy/language coverage preserved;
- short utterances already have little audio to amortize through streaming;
- existing recovery/insertion semantics remain unchanged.

### Long dictations

Evaluate `SlidingWindowAsrManager` from the **pinned** FluidAudio revision.

The goal is not live text UI. The goal is to let old audio windows become inference work while the user is still speaking, so release does not start from zero for a long recording.

Proposed boundary:

1. audio capture remains owned by the current `AudioCapture` implementation;
2. complete windows are offered to a sliding-session object owned by `TranscriptionWorker`;
3. only one inference operation is active at a time;
4. release finalizes the remaining tail and joins the accumulated transcript;
5. the existing deterministic `SuperDictateTextProcessor` remains the single post-ASR pass;
6. history/recovery/insertion remain after final text is known.

## VAD

The pinned FluidAudio revision includes `VadManager`. VAD should initially be used for measurement and optional auto-stop experiments, not to silently delete captured audio.

Potential later behavior:
- configurable silence auto-stop for hands-free mode;
- trim only well-understood leading/trailing silence from inference input;
- never use VAD to mutate the crash-recovery journal source.

## Metrics required before rollout

Measure separately:
- hotkey dispatch → audio armed;
- release → first ASR work still required;
- release → final transcript;
- final transcript → post-processing;
- insertion dispatch;
- end-to-end release → paste;
- real-time factor by audio duration bucket;
- error/fallback rate for sliding sessions.

Compare at least:
- < 3 s;
- 3–10 s;
- 10–30 s;
- 30–120 s;
- > 120 s.

## Rollout rule

Do not replace the batch path globally.

Ship behind an internal/experimental long-dictation threshold first. A sliding result must be able to fall back to the existing batch path using the already-captured source samples if session finalization fails or produces an invalid result.

The product objective is simple: preserve multilingual accuracy and reliability while making long release-to-paste latency approach the cost of the unprocessed tail rather than the cost of the full recording.
