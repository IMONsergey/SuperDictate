# macOS product spine

Status: production architecture boundary.

## Why this exists

The v0.2.37 runtime is reliable but concentrated in `swift/Sources/Parakey/main.swift`. Earlier R&D proved many larger ideas, but also created a long stacked PR chain. The production path now grows from `main` with small reversible slices.

The immediate objective is not to rewrite the runtime. It is to put a stable product-facing seam in front of it.

## Layers

### `SuperDictateCore`

Foundation-only product state and commands.

It may know about:

- Today / Library / Tasks / Ask;
- recordings and transcript text;
- verified tasks;
- high-level capture/processing state;
- user commands.

It must not know about:

- AppKit or SwiftUI;
- FluidAudio / CoreML implementation objects;
- `AVAudioEngine` callbacks;
- TCC reset mechanics;
- update manifests;
- codesigning;
- raw recovery journals/checksums;
- future backend/watch synchronization internals.

### `SuperDictateUI`

Native macOS presentation and semantic design tokens.

It may:

- render product state;
- emit product commands;
- use native macOS controls;
- own product-specific presentation such as document layout.

It must not:

- start or configure speech engines directly;
- read/write product storage directly;
- know updater/download URLs;
- mutate TCC state;
- bypass product commands into monolithic runtime internals.

### `Parakey`

Current runtime adapter.

For now it continues to own the working implementation of:

- global hotkeys;
- audio capture;
- speech model lifecycle;
- transcription;
- insertion;
- current persistence/history;
- permissions/TCC recovery;
- updater and agent behavior;
- existing HUD/control panel.

Over time, deterministic responsibilities can move out behind tests. Hardware-sensitive working code moves only when the seam and regression coverage are ready.

## Integration direction

The next runtime PR should create one adapter that maps existing state into `SuperDictateProductSnapshot` and routes `SuperDictateCommand` back into existing handlers.

That adapter is deliberately narrow:

```text
existing Parakey runtime
        |
        v
SuperDictateProductSnapshot
        |
        v
SuperDictateMainView
        |
        v
SuperDictateCommand
        |
        v
existing Parakey handlers
```

This is the strangler pattern applied to the UI/product boundary: new architecture grows around known-good runtime behavior rather than replacing it wholesale.

## Merge discipline

Each production PR should ideally change one boundary:

1. compile a module;
2. connect one adapter;
3. migrate one deterministic responsibility;
4. add one product capability;
5. preserve existing end-to-end CI.

Do not combine broad formatting, audio refactors, storage migration and interface redesign in one PR.
