# Native product window v2

Status: production integration note.

## Process boundary

SuperDictate continues to use the existing two-process runtime shape:

```text
visible SuperDictate process
  SuperDictateLiveMainView
  NativeProductWindowController
           |
           | trusted local start / stop request
           v
background SuperDictate --agent process
  ParakeyApp
  hotkeys -> audio -> ASR -> text processing -> insertion
```

The redesign does not move audio capture, FluidAudio/CoreML inference, TCC ownership or insertion into the visible window process.

## Visible product window

The primary window is the lightweight native shell defined by Design System v2:

- Today
- Library
- Tasks
- Ask
- global Record / Stop
- document-like recording detail

`SuperDictateMainModel` is retained for the lifetime of the window. Agent state refreshes update only its published snapshot/language, so SwiftUI navigation state is not recreated every polling interval.

## Trusted capture bridge

The visible process can request only two agent operations:

- start capture;
- stop capture.

The agent validates that the sender:

- is another running process;
- has the same bundle identifier;
- runs from the exact same installed app bundle URL;
- is the frontmost process before a start request is accepted.

This is intentionally not a general IPC or automation API. It does not expose transcripts, settings, diagnostics or arbitrary commands.

## System Status migration surface

The previous compact control panel is temporarily retained as **System Status**. It still owns mature controls that have not yet moved into Settings v2:

- background-service state/start/restart/stop;
- macOS permission recovery;
- update status/actions;
- existing operational diagnostics.

System Status is contextual rather than primary chrome:

- available from the More menu;
- available from the attention indicator;
- opening or closing it does not replace/terminate the primary product window.

Capabilities should migrate from this panel into native Settings/attention flows incrementally. Remove the legacy panel only after every required function has a tested replacement.

## Legacy Library limitations

The current Library adapts `recentTranscriptEntries`. That archive does not contain durable recording identity, source capture date or real audio duration.

Therefore v2 currently:

- preserves source ordering;
- creates deterministic temporary IDs from transcript content + duplicate occurrence;
- does **not** fabricate dates/durations;
- does not claim legacy entries have source audio when the archive cannot prove it.

A later storage migration should introduce durable recording IDs and real metadata before richer Library UI is enabled.

## Runtime states

The visible shell distinguishes:

- idle;
- starting;
- recording;
- transcribing;
- ready;
- needs attention.

Record is disabled while the service is starting, transcription is already running, or recovery/permissions require intervention. Stop remains actionable during recording.

## Non-goals of this slice

This integration does not yet add:

- generated tasks;
- grounded Ask;
- summaries;
- people/speaker identity;
- meeting detection;
- new storage schema;
- new ASR engine;
- App Store distribution changes.

Those capabilities must land as independent production slices rather than being simulated in the UI.
