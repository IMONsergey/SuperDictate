# Owned release channel v2

Status: release architecture prepared; current live updater/installer still use the inherited upstream channel.

## Goal

Move SuperDictate distribution to `IMONsergey/SuperDictate` without mixing source ownership, signing identity, update metadata and bundle-ID migration into one risky change.

## Atomic release layout

Each owned GitHub Release should publish these assets together:

```text
SuperDictate.zip
update.json
```

`update.json` contains at minimum:

```json
{
  "version": "x.y.z",
  "sha256": "<64 lowercase hex characters>"
}
```

The release job computes the archive SHA after the final signed/notarized app is zipped, writes the manifest from that exact artifact and uploads both assets to the same release.

This avoids updating `main/update.json` after artifact creation and removes the transient state where a manifest points at a release that does not exist yet (or vice versa).

## Target URLs

After the owned channel is proven:

- manifest: `https://github.com/IMONsergey/SuperDictate/releases/latest/download/update.json`
- artifact: exact release asset URL derived from the verified version, not an arbitrary redirect supplied by content;
- project page: `https://github.com/IMONsergey/SuperDictate`.

## Release gate

Before creating a GitHub Release:

1. repository checks;
2. unchanged Parakey runtime self-tests;
3. complete Core XCTest;
4. release `.app` build;
5. Developer ID codesign with the intended production identity;
6. `codesign --verify --deep --strict`;
7. Apple notarization;
8. staple notarization ticket;
9. verify the stapled app again;
10. package the final app into `SuperDictate.zip`;
11. compute SHA-256 over that exact ZIP;
12. create `update.json` from the exact version + SHA;
13. exercise installer against local copies of those final assets before upload;
14. only then publish release assets.

Current ad-hoc CI codesign is a build-integrity smoke, not a substitute for Developer ID/notarization.

## GitHub Actions secrets

The release workflow should not exist as a fake green path before signing credentials are configured. Expected secret categories:

- Developer ID certificate (`.p12`, base64 or equivalent encrypted secret);
- certificate password;
- Apple notarization credentials (prefer App Store Connect API key/team/issuer or another supported `notarytool` credential flow);
- signing identity name/team metadata if not derivable safely.

Never echo secret contents or full private certificate paths.

## Bootstrap / installer

The current installer has hard-coded release version/SHA defaults. Owned distribution should move the default install path to:

1. fetch the latest owned `update.json` over HTTPS;
2. validate schema, version format and lowercase 64-character SHA;
3. derive the owned release asset URL from the validated version;
4. download the ZIP with byte/redirect limits;
5. verify SHA before extraction;
6. verify bundle identity, architecture and code signature before install.

Environment overrides remain for CI/local smoke tests.

## Rollback

Release metadata must keep enough information to reinstall the previous known-good release. Do not delete older release artifacts as part of publishing a new one.

The updater UI should never auto-delete the currently installed app until the replacement has been fully downloaded and verified and the existing transactional replacement path is ready.

## Architecture policy

First owned release can remain Apple Silicon-only because that matches the current production ASR engine. Do not publish a misleading `universal` artifact until the Intel inference path is actually tested in the same release gate.

Bundle identifier remains `com.local.superdictate` during this release-channel migration. TCC/data/service identity migration is separate work.
