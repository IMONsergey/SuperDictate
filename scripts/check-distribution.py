#!/usr/bin/env python3

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def fail(message: str) -> None:
    raise SystemExit(f"distribution identity check failed: {message}")


def require_match(pattern: str, text: str, label: str) -> str:
    match = re.search(pattern, text, re.MULTILINE)
    if not match:
        fail(f"missing {label}")
    return match.group(1)


config_path = ROOT / "distribution.json"
swift_path = ROOT / "swift/Sources/Parakey/ProductDistribution.swift"
installer_path = ROOT / "install.sh"

config = json.loads(config_path.read_text())
if config.get("schemaVersion") != 1:
    fail("unsupported distribution.json schemaVersion")

product = config.get("product") or {}
release = config.get("releaseChannel") or {}

project_repository = product.get("repository")
bundle_identifier = product.get("bundleIdentifier")
app_name = product.get("appName")
release_repository = release.get("repository")
manifest_repository = release.get("manifestRepository")
mode = release.get("mode")
migration_required = release.get("migrationRequired")

for label, value in [
    ("product.repository", project_repository),
    ("product.bundleIdentifier", bundle_identifier),
    ("product.appName", app_name),
    ("releaseChannel.repository", release_repository),
    ("releaseChannel.manifestRepository", manifest_repository),
    ("releaseChannel.mode", mode),
]:
    if not isinstance(value, str) or not value.strip():
        fail(f"{label} must be a non-empty string")

if project_repository != "IMONsergey/SuperDictate":
    fail("project repository must remain IMONsergey/SuperDictate")
if bundle_identifier != "com.local.superdictate":
    fail("bundle ID changes require an explicit TCC/data migration, not a distribution edit")
if mode not in {"legacy-upstream", "owned"}:
    fail(f"unknown releaseChannel.mode {mode!r}")
if not isinstance(migration_required, bool):
    fail("releaseChannel.migrationRequired must be boolean")
if mode == "legacy-upstream" and not migration_required:
    fail("legacy-upstream mode must stay visibly marked as migrationRequired")
if mode == "owned" and migration_required:
    fail("owned mode must clear migrationRequired")
if mode == "owned" and (release_repository != project_repository or manifest_repository != project_repository):
    fail("owned mode must use the product repository for release and manifest ownership")

swift = swift_path.read_text()
swift_project_repository = require_match(
    r'static let projectRepository = "([^"]+)"', swift, "Swift projectRepository"
)
swift_bundle_identifier = require_match(
    r'static let bundleIdentifier = "([^"]+)"', swift, "Swift bundleIdentifier"
)
swift_release_repository = require_match(
    r'static let releaseRepository = "([^"]+)"', swift, "Swift releaseRepository"
)
swift_manifest_repository = require_match(
    r'static let manifestRepository = "([^"]+)"', swift, "Swift manifestRepository"
)
legacy_flag = require_match(
    r'static let usesLegacyUpstreamReleaseChannel = (true|false)',
    swift,
    "Swift legacy release flag",
) == "true"

expected = {
    "Swift projectRepository": (swift_project_repository, project_repository),
    "Swift bundleIdentifier": (swift_bundle_identifier, bundle_identifier),
    "Swift releaseRepository": (swift_release_repository, release_repository),
    "Swift manifestRepository": (swift_manifest_repository, manifest_repository),
}
for label, (actual, wanted) in expected.items():
    if actual != wanted:
        fail(f"{label}={actual!r}, distribution.json={wanted!r}")

if legacy_flag != (mode == "legacy-upstream"):
    fail("Swift usesLegacyUpstreamReleaseChannel disagrees with distribution.json mode")

installer = installer_path.read_text()
project_default = require_match(
    r'^PROJECT_REPOSITORY="\$\{SUPERDICTATE_PROJECT_REPOSITORY:-([^}]+)\}"$',
    installer,
    "installer PROJECT_REPOSITORY",
)
release_default = require_match(
    r'^RELEASE_REPOSITORY="\$\{SUPERDICTATE_RELEASE_REPOSITORY:-\$\{SUPERDICTATE_REPOSITORY:-([^}]+)\}\}"$',
    installer,
    "installer RELEASE_REPOSITORY",
)
if project_default != project_repository:
    fail(f"installer project repository={project_default!r}, expected {project_repository!r}")
if release_default != release_repository:
    fail(f"installer release repository={release_default!r}, expected {release_repository!r}")

# Keep ownership and binary delivery intentionally separated until an owned,
# signed/notarized artifact + release-attached manifest exist. This guard makes
# an accidental partial switch impossible.
if mode == "legacy-upstream" and release_repository == project_repository:
    fail("legacy-upstream mode cannot silently point at the owned product repository")

print(
    "distribution identity ok: "
    f"project={project_repository} release={release_repository} mode={mode}"
)
