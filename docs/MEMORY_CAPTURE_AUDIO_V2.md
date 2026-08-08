# Memory Capture audio v2

Status: macOS architecture prepared against Apple ScreenCaptureKit + the current SuperDictate microphone capture path. No capture runtime is wired in this branch.

## Product split

### Instant Dictation

Keep the current microphone-only `AudioCapture` path.

Reasons:

- global dictation must stay permission-light and fast;
- it already has tested hotkey/audio/recovery behavior;
- it does not need remote participant audio;
- adding Screen Recording permission to basic dictation would be a product regression.

### Memory Capture

A meeting/long-form memory session needs two independent sources:

1. **microphone track** — the current AVAudioEngine capture path, owned by SuperDictate;
2. **system/app audio track** — ScreenCaptureKit audio output for remote participants / meeting playback.

Do not mix these sources at capture time.

## Why separate tracks

Keeping `mic` and `system` source tracks separate gives the product stronger evidence than a permanently mixed stream:

- microphone track is a high-confidence local-speaker source;
- system track contains remote participants and can be diarized separately;
- echo/crosstalk suppression experiments can be repeated from source tracks;
- failed mix/downsample logic cannot destroy the authoritative source;
- export can choose mixed or separate tracks later;
- ASR can process derived 16 kHz mono audio without reducing the quality or identity of the stored source package.

## ScreenCaptureKit boundary

Apple ScreenCaptureKit is the native system-audio source on supported macOS.

Production configuration requirements:

- audio capture explicitly enabled;
- use an audio stream output (`SCStreamOutputType.audio`);
- configure the source with the narrowest practical `SCContentFilter`;
- exclude SuperDictate's own process audio when the selected content would otherwise include it, so UI cues/feedback do not recursively enter the meeting recording;
- request Screen Recording permission only when the person explicitly starts or configures Memory Capture system audio;
- do not make that permission a readiness requirement for Instant Dictation.

Apple recommends its system sharing picker for selecting/manageable capture sources. Evaluate `SCContentSharingPicker` for the first user-facing source selector instead of inventing a custom list of every screen/window/app.

## macOS 14 baseline

Do not rely on newer ScreenCaptureKit microphone-convenience APIs for the baseline implementation.

SuperDictate already has a tested microphone capture engine on macOS 14. Keep microphone capture there and use ScreenCaptureKit for the system/app track. A future newer-OS adapter may consolidate sources only if it preserves the same Core session contract and is measurably more reliable.

## Source format and derived inference audio

The durable package and the inference stream are different concepts.

For the first production spike:

- store each source in Apple-native CAF chunks;
- use a well-supported PCM format first so crash/finalization behavior is easy to reason about;
- create derived 16 kHz mono Float32 only for ASR/VAD/diarization APIs;
- do not persist a lossy derived mix as the only source;
- benchmark compressed CAF only after reliability, CPU, battery, size and seek tests are in place.

Uncompressed source size is potentially large. Production Memory Capture must therefore expose storage pressure and eventually support an explicit compression/retention policy rather than silently filling disk.

## Timeline alignment

Mic and system audio arrive through different capture frameworks and callback queues. Never align them by "callback happened at roughly the same time".

The Memory Capture session owns one monotonic session timeline. Each source adapter records source timing metadata and maps it onto that session timeline before writing chunk descriptors.

Required output per source chunk:

- recording/session UUID;
- source kind (`microphone` / `system`);
- source sequence number;
- session-relative start/end time;
- sample rate/channel count;
- finalized byte length;
- SHA-256;
- immutable file reference.

If timestamp alignment is not trustworthy, preserve the separate tracks and surface the session as needing recovery/realignment rather than fabricating precision.

## Capture package target

```text
recordings/<recording-id>/
  manifest.json
  microphone/
    <sequence>__<chunk-id>.caf
  system/
    <sequence>__<chunk-id>.caf
  quarantine/
  recovery-journal.jsonl
```

The background agent remains the only writer.

## ASR strategy

### Local microphone speaker

The mic track can be tagged as the local speaker source before generic diarization.

### Remote/system participants

Run ASR and diarization on the system track. The pinned FluidAudio revision exposes offline diarization that can consume disk-backed audio sources, which is preferable for long meetings over materializing hours of Float samples in RAM.

### Combined transcript

Merge source transcripts by the session timeline into one evidence document. The merge result must retain source/timing identity so clicking a citation can seek to the corresponding source audio later.

Do not collapse source identity into display text like `Speaker 1`.

## Failure semantics

- microphone succeeds, system permission denied -> allow mic-only Memory Capture if the person explicitly accepts the limitation;
- system source disappears mid-session -> keep already-finalized system chunks, continue mic if safe, surface attention;
- ScreenCaptureKit stream fails -> never stop/erase microphone source automatically;
- microphone route changes -> use existing audio-route recovery logic, do not restart system source unless required;
- disk pressure -> stop safely before corrupting the package;
- app crash -> finalized chunks remain recoverable; partial chunks quarantine;
- source timing discontinuity -> preserve bytes and mark attention; never invent timestamps.

## Permissions UX

The primary dictation readiness state remains unchanged.

Memory Capture setup may show a contextual system-audio requirement:

- Microphone: already part of SuperDictate dictation permission set;
- Screen Recording: requested only for system/app audio capture.

The product must explain that Screen Recording permission is needed by macOS for capturing another app's audio, even when SuperDictate is not interested in recording visible pixels.

## First implementation sequence

1. durable recording identity + crash journal metadata;
2. `SuperDictateCaptureKind.memoryRecording`;
3. durable two-source session manifest;
4. CAF microphone chunk adapter;
5. ScreenCaptureKit system-audio proof of concept with explicit source picker;
6. source timeline alignment tests;
7. independent source playback/export smoke;
8. derived 16 kHz ASR streams;
9. remote diarization + stable speaker assignments;
10. evidence timeline merge;
11. only then auto-summary/tasks/Ask on meeting evidence.

## Explicit non-goals for the first slice

- no screen/video recording product;
- no hidden always-on system audio capture;
- no automatic meeting bot joining calls;
- no cloud transcription by default;
- no premature real-time mixed transcript if it weakens recovery/source truth.
