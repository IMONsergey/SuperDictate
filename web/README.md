# SuperDictate Web Workbench

Local static preview for the product workbench. It is intentionally dependency-free so it can run on an Intel Mac before the native Intel runtime is finished.

Run from the repository root:

```bash
python3 -m http.server 5173 --bind 127.0.0.1
```

Open:

```text
http://127.0.0.1:5173/web/
```

If the port is busy, use any free local port and replace it in the URL.

Current preview surface:

- microphone recording through the browser MediaRecorder API;
- chunk sealing, byte counts and SHA-256 verification;
- marker capture;
- local recovery journal with crash/recover simulation;
- app-style navigation across Today, Capture, Library, Transcript, AI Review,
  Tasks, Ask, People, Models, Settings and Export;
- model selection, with Whisper.cpp Small shown as the recommended Intel UX
  target while the current native bootstrap still installs Whisper.cpp Base;
- transcript paste/browser speech entry and rule-based local AI Review/actions;
- evidence chips, mind-map preview, Ask scope chips and calendar task scheduling
  for product-flow testing;
- one-click demo flow and JSON export for quick product review.

Native Intel transcription is tracked separately in the `feature/intel-whisper-model-choice` branch and will use a local `whisper-cli` runtime.

Design direction is tracked in `docs/DESIGN_REFERENCE_SYSTEM.md` and
`docs/POCKET_ALTERNATIVE_PRODUCT_RESEARCH.md`.
