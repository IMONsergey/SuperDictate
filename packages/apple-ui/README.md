# SuperDictateAppleUI

SwiftUI workbench components for SuperDictate native apps.

## Responsibilities

- render `SuperDictateWorkbenchState`;
- expose recorder, processing, transcript, summary, actions and models tabs;
- show local model readiness and install state;
- keep review and recovery status visible;
- provide native command hooks without owning recording or model runtime logic.

## Explicitly outside this package

- microphone capture;
- model downloads;
- transcription runtime binaries;
- persistence;
- AppKit menu bar integration;
- iOS/watchOS navigation shell.

The UI package depends only on `SuperDictateCore`. Platform apps pass state in and handle commands such as record, stop, recover and review.

## Build

```bash
swift build --package-path packages/apple-ui
```
