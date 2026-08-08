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

Processing order remains:

1. trim raw ASR output;
2. repair known speech-model artifacts;
3. apply explicit user corrections;
4. optionally remove conservative filler words.

The existing Parakey self-test suite continues to exercise the legacy entry point, so a behavioral mismatch between the old runtime contract and the shared Core implementation fails the normal production gate.

## Release validation

The final migration head is validated only by the standard read-only production workflow: repository checks, the unchanged Parakey runtime self-test suite, the complete `SuperDictateCoreTests` suite, release app bundle build, strict codesign verification, and real installer/uninstaller smoke. The one-shot patch workflow is not treated as the release signal.

## Follow-up cleanup

After this migration has remained green, duplicated legacy implementations (`SpeechModelTextRepair`, `TranscriptCorrector`, `FillerWordRemover`) can be removed from `main.swift` only after repository-wide reference checks confirm that no non-test path still depends on them.
