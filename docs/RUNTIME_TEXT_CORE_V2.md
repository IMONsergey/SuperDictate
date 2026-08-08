# Runtime text processing core v2

Status: production migration note.

## Runtime boundary

The existing `processedDictationText` entry point remains in the macOS runtime so audio/ASR/insertion call sites and legacy self-test fixtures do not change as part of this migration.

Its implementation delegates deterministic post-ASR processing to `SuperDictateTextProcessor` through `ProductTextProcessingAdapter.swift`.

The runtime mapping is:

- `DictationLanguage.auto` -> `SuperDictateTextLanguage.auto`;
- `DictationLanguage.russian` -> `SuperDictateTextLanguage.russian`;
- every other explicit language -> `SuperDictateTextLanguage.other`;
- `TranscriptCorrection` -> `SuperDictateTextCorrection`.

## Compatibility invariant

Processing order remains: trim raw ASR output; repair known speech-model artifacts; apply explicit user corrections; optionally remove conservative filler words.

The existing Parakey self-test suite remains unchanged and therefore acts as the runtime compatibility oracle. The complete `SuperDictateCoreTests` suite, release app bundle build, strict codesign verification and installer/uninstaller smoke remain required release gates.

## Follow-up cleanup

After this migration has remained green, duplicated legacy implementations (`SpeechModelTextRepair`, `TranscriptCorrector`, `FillerWordRemover`) can be removed from `main.swift` only after their remaining direct self-tests are migrated to Core.
