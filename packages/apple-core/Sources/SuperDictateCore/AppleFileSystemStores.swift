import Foundation

public enum FileSystemStoreError: Error, Equatable, Sendable {
    case manifestIdentityMismatch
    case unsupportedFileType
}

public actor JSONRecordingManifestStore: RecordingManifestStore {
    private let rootDirectory: URL
    private let recordingsDirectory: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        rootDirectory: URL,
        fileManager: FileManager = .default
    ) throws {
        self.rootDirectory = rootDirectory
        self.recordingsDirectory = rootDirectory
            .appendingPathComponent("recordings", isDirectory: true)
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        self.decoder = decoder

        try fileManager.createDirectory(
            at: recordingsDirectory,
            withIntermediateDirectories: true
        )
    }

    public func load(recordingID: UUID) async throws -> LocalRecordingManifest? {
        let url = manifestURL(recordingID: recordingID)
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }

        let manifest = try decodeManifest(at: url)
        guard manifest.id == recordingID else {
            throw FileSystemStoreError.manifestIdentityMismatch
        }
        return manifest
    }

    public func save(_ manifest: LocalRecordingManifest) async throws {
        let packageDirectory = packageDirectory(recordingID: manifest.id)
        try fileManager.createDirectory(
            at: packageDirectory,
            withIntermediateDirectories: true
        )

        let data = try encoder.encode(manifest)
        try data.write(
            to: manifestURL(recordingID: manifest.id),
            options: [.atomic]
        )
    }

    public func listPendingTransfer() async throws -> [LocalRecordingManifest] {
        let packageURLs = try fileManager.contentsOfDirectory(
            at: recordingsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        var manifests: [LocalRecordingManifest] = []

        for packageURL in packageURLs {
            let values = try packageURL.resourceValues(forKeys: [.isDirectoryKey])
            guard values.isDirectory == true else {
                continue
            }

            let url = packageURL.appendingPathComponent("manifest.json")
            guard fileManager.fileExists(atPath: url.path) else {
                continue
            }

            let manifest = try decodeManifest(at: url)
            guard isPendingTransfer(manifest.localState) else {
                continue
            }
            manifests.append(manifest)
        }

        return manifests.sorted { lhs, rhs in
            if lhs.updatedAt != rhs.updatedAt {
                return lhs.updatedAt < rhs.updatedAt
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    public func removeLocalSource(recordingID: UUID) async throws {
        let directory = packageDirectory(recordingID: recordingID)
        guard fileManager.fileExists(atPath: directory.path) else {
            return
        }
        try fileManager.removeItem(at: directory)
    }

    public func packageURL(recordingID: UUID) -> URL {
        packageDirectory(recordingID: recordingID)
    }

    private func packageDirectory(recordingID: UUID) -> URL {
        recordingsDirectory.appendingPathComponent(
            recordingID.uuidString.lowercased(),
            isDirectory: true
        )
    }

    private func manifestURL(recordingID: UUID) -> URL {
        packageDirectory(recordingID: recordingID)
            .appendingPathComponent("manifest.json")
    }

    private func decodeManifest(at url: URL) throws -> LocalRecordingManifest {
        let data = try Data(contentsOf: url)
        return try decoder.decode(LocalRecordingManifest.self, from: data)
    }

    private func isPendingTransfer(_ state: LocalRecordingState) -> Bool {
        switch state {
        case .finalized, .queued, .transferring, .needsAttention:
            return true
        case .open,
             .finalizing,
             .uploaded,
             .processing,
             .ready,
             .deletionPending,
             .deleted:
            return false
        }
    }
}

public actor JSONUploadQueueStore: UploadQueueStore {
    private let rootDirectory: URL
    private let queueDirectory: URL
    private let queueURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        rootDirectory: URL,
        fileManager: FileManager = .default
    ) throws {
        self.rootDirectory = rootDirectory
        self.queueDirectory = rootDirectory
            .appendingPathComponent("sync", isDirectory: true)
        self.queueURL = queueDirectory
            .appendingPathComponent("upload-queue.json")
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        self.decoder = decoder

        try fileManager.createDirectory(
            at: queueDirectory,
            withIntermediateDirectories: true
        )
    }

    public func loadQueue() async throws -> UploadQueue {
        guard fileManager.fileExists(atPath: queueURL.path) else {
            return UploadQueue()
        }

        let data = try Data(contentsOf: queueURL)
        return try decoder.decode(UploadQueue.self, from: data)
    }

    public func saveQueue(_ queue: UploadQueue) async throws {
        try fileManager.createDirectory(
            at: queueDirectory,
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(queue)
        try data.write(to: queueURL, options: [.atomic])
    }

    public func storageURL() -> URL {
        queueURL
    }
}
