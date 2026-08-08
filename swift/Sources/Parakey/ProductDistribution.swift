import Foundation

/// Explicit product/distribution identity.
///
/// `projectRepository` is SuperDictate's source-of-truth repository. The release
/// channel is intentionally separate while the current install/update artifacts
/// are still inherited from the upstream project. Keeping that transition visible
/// prevents the app from silently presenting an upstream URL as its own product
/// identity and gives the future signed release pipeline one migration seam.
enum ProductDistribution {
    static let projectRepository = "IMONsergey/SuperDictate"
    static let bundleIdentifier = "com.local.superdictate"

    /// Transitional only. Switch together with the owned release artifact,
    /// manifest, checksum and updater verification path.
    static let releaseRepository = "shlgd/SuperDictate"
    static let manifestRepository = "shlgd/SuperDictate"
    static let usesLegacyUpstreamReleaseChannel = true

    static var projectPage: URL {
        URL(string: "https://github.com/\(projectRepository)")!
    }

    static var latestReleaseAPI: URL {
        URL(string: "https://api.github.com/repos/\(releaseRepository)/releases/latest")!
    }

    static var latestReleasePage: URL {
        URL(string: "https://github.com/\(releaseRepository)/releases/latest")!
    }

    static var updateManifestURL: URL {
        URL(string: "https://raw.githubusercontent.com/\(manifestRepository)/main/update.json")!
    }
}
