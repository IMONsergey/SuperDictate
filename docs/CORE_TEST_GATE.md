# SuperDictate Core test gate

Status: production CI contract.

The macOS build workflow must execute the complete `SuperDictateCoreTests` XCTest target on every pull request rather than filtering to one historical test class.

This matters because the production Core now owns independently testable behavior for:

- product navigation/state;
- deterministic text processing;
- private durable Library storage and migration;
- local evidence retrieval;
- Library reconciliation and persistence helpers as they land.

Compilation alone is not a release gate. Assertions in every Core test file must execute before the app bundle, codesign and installer smoke stages are allowed to represent a green change.

The separate `Parakey --self-test all` step remains required for the existing monolithic runtime regression suite. Core XCTest is an additional extraction boundary, not a replacement for the mature runtime self-tests.
