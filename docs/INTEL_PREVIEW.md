# Intel Mac Preview

Production releases are still Apple Silicon-first. Intel support is a local preview path for testing the product while the native runtime is being hardened.

## What to Install

1. Apple Command Line Tools:

```bash
xcode-select --install
```

2. Homebrew, if it is not installed:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

3. CMake:

```bash
brew install cmake
```

4. Whisper.cpp runtime and the first test model:

```bash
cd /Users/erdc/Documents/SuperDictate
scripts/setup-whisper-intel.sh
```

The setup script installs:

- `~/Library/Application Support/SuperDictate/whisper.cpp/whisper-cli`;
- `~/Library/Application Support/SuperDictate/Models/whisper.cpp/base/ggml-base.bin`.

## First Model Choice

Current native bootstrap: use `Whisper.cpp Base`.

It is the best first Intel test profile because it is free, offline, multilingual, small enough for CPU testing, and good enough for Russian/English dictation experiments. `tiny` is faster but noticeably weaker; `small` is a better later quality target after latency and packaging are stable.

Current web product preview: `Whisper.cpp Small` is shown as the recommended
Intel UX target because it is the better product-quality default once the native
model manager supports multiple downloads. Until `scripts/setup-whisper-intel.sh`
adds model selection, the native Intel runtime still expects `ggml-base.bin`.

## Run the Web Workbench

This gives an immediate UI preview with microphone capture, chunks, markers,
recovery journal, model selection, Today/Capture/Library navigation, transcript
processing, local rule-based AI Review/actions, evidence chips, Ask preview and
calendar task scheduling:

```bash
cd /Users/erdc/Documents/SuperDictate
python3 -m http.server 5173 --bind 127.0.0.1
```

Open:

```text
http://127.0.0.1:5173/web/
```

## Build the Native Intel Preview

From the repository checkout:

```bash
cd /Users/erdc/Documents/SuperDictate
SUPERDICTATE_ENABLE_INTEL_PREVIEW=1 ./scripts/build-app.sh ./dist/SuperDictate.app
open ./dist/SuperDictate.app
```

Then choose:

```text
Settings -> Dictation -> Speech Model -> Whisper.cpp Base
```

If the app says `whisper-cli` or `ggml-base.bin` is missing, rerun:

```bash
scripts/setup-whisper-intel.sh
```

## Current Limitations

- The public ZIP installer still targets Apple Silicon.
- Intel preview must be built from source for now.
- The first Intel backend shells out to local `whisper-cli`; deeper in-process integration comes later.
- Browser speech in the web workbench is only a UI convenience when the browser supports it. The native Intel path is `whisper.cpp`.
