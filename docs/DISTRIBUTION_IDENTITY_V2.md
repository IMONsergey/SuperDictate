# Distribution identity v2

Status: prepared production foundation; not yet wired into the live updater/installer.

## Problem

SuperDictate's source of truth is `IMONsergey/SuperDictate`, but the current inherited release/update channel still points at `shlgd/SuperDictate`. Those are different concerns and must not remain hidden behind one `REPOSITORY` constant.

## Explicit identities

`distribution.json` separates:

- **product/source repository:** `IMONsergey/SuperDictate`;
- **bundle identifier:** `com.local.superdictate`;
- **current release repository:** `shlgd/SuperDictate` (temporary legacy channel);
- **current update-manifest repository:** `shlgd/SuperDictate` (temporary legacy channel).

`ProductDistribution.swift` mirrors the runtime-facing values until the generated-config step is introduced.

## Migration rule

Do not switch the default release/update repository to `IMONsergey/SuperDictate` until all of these exist and pass the normal release gate:

1. an owned release artifact in the project repository;
2. SHA-256 pinned in the owned `update.json`;
3. installer verification against that artifact;
4. updater verification against the owned manifest/release;
5. release build codesign/notarization policy decided and tested;
6. rollback path to the previous version documented.

The switch must change the release repository and manifest repository together. A mixed channel is not supported.

## Bundle identity is a separate migration

Do **not** combine repository ownership with a bundle-ID rename.

`com.local.superdictate` is already entangled with:

- macOS TCC grants;
- LaunchAgent/service identity;
- UserDefaults suite;
- Application Support data;
- Library/history state;
- existing recovery/update behavior.

Changing it requires a dedicated migration that preserves permissions/data or explicitly guides the user through the consequences. Until that work exists, owned distribution should keep the current bundle identifier and storage paths.

## Target architecture

The live runtime/installer should eventually consume one generated distribution contract derived from `distribution.json`. `scripts/check.sh` should fail when generated Swift/shell constants drift from that file.

The current branch intentionally stops before replacing live URLs: abstraction first, channel switch only with a verifiable owned release.
