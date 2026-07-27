# ADR 0001: Native clients with a shared service contract

- Status: Accepted
- Date: 2026-07-27
- Owners: SuperDictate product and engineering

## Context

SuperDictate must support macOS, iOS, watchOS, Android and Wear OS. Audio capture, background execution, watch connectivity, complications, tiles, permissions and lifecycle behavior are platform-sensitive. A single cross-platform UI layer would reduce initial file count but would increase risk in the product's most important function: reliable recording and delivery of audio.

The existing application is native Swift on macOS and already contains working audio, permission and local-transcription behavior that must not be discarded.

## Decision

Use native applications on each platform family:

- Swift, SwiftUI and native Apple frameworks for macOS, iOS and watchOS;
- Kotlin, Jetpack Compose and native Android frameworks for Android and Wear OS.

Share behavior through:

- a versioned OpenAPI contract;
- generated API clients;
- a shared database and processing model;
- platform-family domain modules;
- common fixtures, schemas, feature flags and conformance tests.

Create `SuperDictateCore` as a Swift package for Apple-domain behavior and equivalent Kotlin domain modules for Android.

## Consequences

### Positive

- reliable native audio-session and background behavior;
- full access to watch complications, Wear OS tiles and platform haptics;
- incremental reuse of the existing macOS code;
- independent release cadence for platform clients;
- API conformance can be tested without sharing UI implementation;
- fewer hidden limitations from framework plugins.

### Negative

- two client technology stacks;
- duplicated presentation code;
- additional release pipelines;
- product behavior can drift unless contract and conformance tests are enforced.

## Guardrails

- Business entities and processing states are defined in the API contract, not invented separately in each client.
- Recording files are written locally before any upload begins.
- Every mutation uses an idempotency key.
- Watch clients remain useful without an active phone connection.
- Platform-specific code must sit behind explicit adapters rather than leaking into shared domain logic.
- Existing macOS dictation behavior receives regression tests before extraction into shared packages.

## Rejected alternatives

### Flutter for all clients

Rejected for the foundation because watchOS support and background audio workflows would require substantial native bridging, undermining the main benefit of one UI codebase.

### React Native for all clients

Rejected for the same reason, with additional lifecycle and bridge complexity around long-running recording and wearable targets.

### Web/PWA as the primary mobile client

Rejected because browser recording, background execution, wearable integration and offline reliability are insufficient for the product promise.

### Rewrite the existing macOS application first

Rejected because a broad rewrite would delay the first cross-platform vertical slice and risk breaking a working product.
