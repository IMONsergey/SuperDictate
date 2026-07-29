# Apple audio capture adapter

## Scope

This slice defines the Apple capture adapter boundary that sits between native AVFoundation runtime code and `SuperDictateCore` durable recording packages.

The adapter is responsible for:

- record permission state;
- audio session activation and deactivation;
- explicit start, pause, resume and stop;
- interruption handling;
- route change handling;
- background and extended-runtime policy decisions;
- input format selection;
- level metering;
- marker emission;
- chunk writer integration.

The current PR keeps hardware-sensitive behavior behind protocols and a pure coordinator. It does not replace the existing macOS `AudioCapture` monolith yet.

## Runtime boundary

`AppleAudioCaptureCoordinator` is deterministic and testable. It receives events and returns effects:

```text
start requested          -> request permission or activate session + begin chunked recording
permission granted       -> activate session + begin chunked recording
interruption began       -> pause engine
interruption ended       -> resume only when recording was active and the system allows resume
route changed            -> refresh route without changing recording state
stop requested           -> stop engine + finalize recording
writer finalized         -> deactivate session
marker requested         -> emit marker only while capture is active/paused/interrupted
```

The platform adapter executes those effects with AVFoundation and `ChunkFileWriter`. Unit tests cover the decision layer; hardware tests must cover the concrete adapter.

## iOS plan

- Use `AVAudioSession` with an explicit record category and spoken-audio oriented mode after device validation.
- Request record permission before session activation.
- Prefer Bluetooth input only when the route is stable and user-visible.
- Treat phone calls and system interruptions as first-class lifecycle events.
- Resume after interruption only when the system says resume is allowed and capture was active before the interruption.
- Use background audio only with a user-visible recording state and a product justification.

## watchOS plan

- Use an extended runtime session only for visible recording.
- Keep battery and storage pressure visible; never hide recording from the user.
- Do not misuse workout APIs for generic recording.
- Preserve local chunks when the companion is unavailable.
- Treat haptics as status feedback, not as the source of truth.
- Validate screen-off behavior on physical hardware.

## Manual test checklist

- Fresh install permission prompt: allow and deny paths.
- Start, pause, resume and stop with a visible timer/status.
- Add marker while recording and while paused.
- Start with Bluetooth input connected, then disconnect it.
- Start on built-in microphone, then connect Bluetooth input.
- Receive a phone call or system interruption during recording.
- Lock screen during recording and verify visible system recording indicators.
- Force-kill after active chunk write but before stop; recovery must quarantine partial bytes.
- Force-kill after finalized chunk file but before manifest commit; recovery must append the chunk once.
- Fill storage below the low-storage threshold; capture must fail visibly without deleting source bytes.
- Watch: screen off, companion unavailable, low battery, and direct-network unavailable cases.

## Simulator limitations

Simulator can exercise coordinator state, permission-denied UI branches and some route notifications. It cannot prove microphone timing, Bluetooth routing, interruption behavior, watchOS extended runtime limits, power loss, or storage-pressure behavior. Those require physical device runs.
