from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected one source match, found {count}")
    return text.replace(old, new, 1)


install_path = Path("install.sh")
install = install_path.read_text()
install = replace_once(
    install,
    'REPOSITORY="${SUPERDICTATE_REPOSITORY:-shlgd/SuperDictate}"\n',
    'PROJECT_REPOSITORY="${SUPERDICTATE_PROJECT_REPOSITORY:-IMONsergey/SuperDictate}"\n'
    'RELEASE_REPOSITORY="${SUPERDICTATE_RELEASE_REPOSITORY:-${SUPERDICTATE_REPOSITORY:-shlgd/SuperDictate}}"\n',
    "installer repository split",
)
install = replace_once(
    install,
    'RELEASE_URL="${SUPERDICTATE_RELEASE_URL:-https://github.com/$REPOSITORY/releases/download/v$RELEASE_VERSION/SuperDictate.zip}"\n',
    'RELEASE_URL="${SUPERDICTATE_RELEASE_URL:-https://github.com/$RELEASE_REPOSITORY/releases/download/v$RELEASE_VERSION/SuperDictate.zip}"\n',
    "release URL repository",
)
install = replace_once(
    install,
    '"https://api.github.com/repos/$REPOSITORY/commits/$REF"',
    '"https://api.github.com/repos/$PROJECT_REPOSITORY/commits/$REF"',
    "source commit verification repository",
)
install = replace_once(
    install,
    '"https://github.com/$REPOSITORY/archive/$REF.zip"',
    '"https://github.com/$PROJECT_REPOSITORY/archive/$REF.zip"',
    "source archive repository",
)
install_path.write_text(install)

main_path = Path("swift/Sources/Parakey/main.swift")
main = main_path.read_text()
main = replace_once(
    main,
    'let GITHUB_LATEST_RELEASE_URL = URL(string: "https://api.github.com/repos/shlgd/SuperDictate/releases/latest")!\n'
    'let GITHUB_REPOSITORY_PAGE = URL(string: "https://github.com/shlgd/SuperDictate")!\n'
    'let GITHUB_RELEASES_PAGE = URL(string: "https://github.com/shlgd/SuperDictate/releases/latest")!\n'
    'let GITHUB_UPDATE_MANIFEST_URL = URL(string: "https://raw.githubusercontent.com/shlgd/SuperDictate/main/update.json")!\n',
    'let GITHUB_LATEST_RELEASE_URL = ProductDistribution.latestReleaseAPI\n'
    'let GITHUB_REPOSITORY_PAGE = ProductDistribution.projectPage\n'
    'let GITHUB_RELEASES_PAGE = ProductDistribution.latestReleasePage\n'
    'let GITHUB_UPDATE_MANIFEST_URL = ProductDistribution.updateManifestURL\n',
    "runtime distribution URLs",
)
main_path.write_text(main)
