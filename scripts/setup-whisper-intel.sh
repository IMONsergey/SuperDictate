#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_SUPPORT_DIR="${SUPERDICTATE_APP_SUPPORT_DIR:-$HOME/Library/Application Support/SuperDictate}"
RUNTIME_DIR="$APP_SUPPORT_DIR/whisper.cpp"
SOURCE_DIR="$RUNTIME_DIR/source"
BUILD_DIR="$RUNTIME_DIR/build"
CLI_TARGET="$RUNTIME_DIR/whisper-cli"
MODEL_DIR="$APP_SUPPORT_DIR/Models/whisper.cpp/base"
MODEL_FILE="$MODEL_DIR/ggml-base.bin"
WHISPER_CPP_REF="${SUPERDICTATE_WHISPER_CPP_REF:-v1.8.6}"

say() {
    printf 'SuperDictate whisper.cpp setup: %s\n' "$*"
}

fail() {
    printf 'SuperDictate whisper.cpp setup: %s\n' "$*" >&2
    exit 1
}

[[ "$(/usr/bin/uname -s)" == "Darwin" ]] || fail "macOS is required."
command -v git >/dev/null 2>&1 || fail "git is missing. Run: xcode-select --install"
command -v cmake >/dev/null 2>&1 || fail "cmake is missing. Install Homebrew, then run: brew install cmake"
xcrun --find clang >/dev/null 2>&1 || fail "Apple Command Line Tools are missing. Run: xcode-select --install"

mkdir -p "$RUNTIME_DIR" "$MODEL_DIR"

if [[ -d "$SOURCE_DIR/.git" ]]; then
    say "Updating whisper.cpp source at $SOURCE_DIR"
    git -C "$SOURCE_DIR" fetch --tags --depth 1 origin "$WHISPER_CPP_REF"
    git -C "$SOURCE_DIR" checkout --detach FETCH_HEAD
elif [[ -e "$SOURCE_DIR" ]]; then
    fail "$SOURCE_DIR exists but is not a git checkout. Move it away or set SUPERDICTATE_APP_SUPPORT_DIR."
else
    say "Cloning whisper.cpp $WHISPER_CPP_REF"
    git clone --depth 1 --branch "$WHISPER_CPP_REF" https://github.com/ggml-org/whisper.cpp.git "$SOURCE_DIR"
fi

say "Building whisper-cli"
cmake -S "$SOURCE_DIR" -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE=Release
cmake --build "$BUILD_DIR" --config Release -j "$(/usr/sbin/sysctl -n hw.ncpu)"

BUILT_CLI=""
for candidate in \
    "$BUILD_DIR/bin/whisper-cli" \
    "$BUILD_DIR/bin/Release/whisper-cli" \
    "$BUILD_DIR/examples/cli/whisper-cli" \
    "$BUILD_DIR/examples/cli/Release/whisper-cli"
do
    if [[ -x "$candidate" ]]; then
        BUILT_CLI="$candidate"
        break
    fi
done

if [[ -z "$BUILT_CLI" ]]; then
    BUILT_CLI="$(find "$BUILD_DIR" -type f -name whisper-cli -print -quit)"
fi
[[ -n "$BUILT_CLI" && -x "$BUILT_CLI" ]] || fail "Built whisper-cli was not found under $BUILD_DIR"

cp "$BUILT_CLI" "$CLI_TARGET"
chmod 755 "$CLI_TARGET"

if [[ -f "$MODEL_FILE" ]]; then
    say "Model already installed at $MODEL_FILE"
else
    say "Downloading Whisper Base multilingual model"
    (cd "$SOURCE_DIR" && sh ./models/download-ggml-model.sh base)
    [[ -f "$SOURCE_DIR/models/ggml-base.bin" ]] || fail "Model download did not produce models/ggml-base.bin"
    cp "$SOURCE_DIR/models/ggml-base.bin" "$MODEL_FILE"
fi

"$CLI_TARGET" -h >/dev/null 2>&1 || fail "whisper-cli did not start correctly."

say "Ready."
printf '\nExecutable: %s\n' "$CLI_TARGET"
printf 'Model:      %s\n' "$MODEL_FILE"
printf '\nUse SuperDictate Settings -> Dictation -> Speech Model -> Whisper.cpp Base.\n'
printf 'For manual overrides:\n'
printf '  export SUPERDICTATE_WHISPER_CPP_CLI=%q\n' "$CLI_TARGET"
printf '  export SUPERDICTATE_WHISPER_CPP_MODEL=%q\n' "$MODEL_FILE"
