import Foundation

public enum SuperDictateLibraryStoreError: Error, Equatable, Sendable {
    case unsupportedSchema(Int)
    case unsafeFileType
    case fileTooLarge(Int, Int)
    case tooManyRecordings(Int, Int)
    case tooManyTasks(Int, Int)
    case tooManyMemoryDocuments(Int, Int)
    case duplicateRecording(UUID)
    case duplicateTask(UUID)
    case duplicateMemoryDocument(UUID)
}

public struct SuperDictateLibraryArchive: Codable, Equatable, Sendable {
    public var recordings: [SuperDictateRecording]
    public var tasks: [SuperDictateTask]
    public var memoryDocuments: [SuperDictateMemoryDocument]

    public init(
        recordings: [SuperDictateRecording] = [],
        tasks: [SuperDictateTask] = [],
        memoryDocuments: [SuperDictateMemoryDocument] = []
    ) {
        self.recordings = recordings
        self.tasks = tasks
        self.memoryDocuments = memoryDocuments
    }

    public var snapshot: SuperDictateProductSnapshot {
        SuperDictateProductSnapshot(
            recordings: recordings,
            tasks: tasks
        )
    }

    public var memoryIndex: SuperDictateLocalMemoryIndex {
        SuperDictateLocalMemoryIndex(documents: memoryDocuments)
    }
}

public protocol SuperDictateLibraryStoring: Sendable {
    func load() async throws -> SuperDictateLibraryArchive
    func save(_ archive: SuperDictateLibraryArchive) async throws
    func upsertRecording(
        _ recording: SuperDictateRecording,
        memoryDocument: SuperDictateMemoryDocument?
    ) async throws
    func upsertTask(_ task: SuperDictateTask) async throws
    func removeRecordingFromIndex(_ recordingID: UUID) async throws
}

private struct SuperDictateLibraryFile: Codable, Sendable {
    let schemaVersion: Int
    let updatedAt: Date
    let archive: SuperDictateLibraryArchive
}

/// Private, rebuildable product index for Today / Library / Tasks / Ask.
///
/// This is intentionally separate from authoritative source audio and runtime
/// recovery files. Removing an item from this index never deletes source audio.
/// The index may contain transcript text, people and task metadata, so it is
/// treated as sensitive local data even though it is rebuildable.
public actor JSONSuperDictateLibraryStore: SuperDictateLibraryStoring {
    public static let schemaVersion = 1
    public static let maximumFileBytes = 64 * 1_024 * 1_024
    public static let maximumRecordings = 50_000
    public static let maximumTasks = 100_000
    public static let maximumMemoryDocuments = 50_000

    private let directoryURL: URL
    private let fileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        rootDirectory: URL,
        fileManager: FileManager = .default
    ) throws {
        self.directoryURL = rootDirectory.appendingPathComponent(
            "library",
            isDirectory: true
        )
        self.fileURL = directoryURL.appendingPathComponent(
            "index.json",
            isDirectory: false
        )
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        self.decoder = decoder

        try Self.ensurePrivateDirectory(directoryURL, fileManager: fileManager)
    }

    public func load() async throws -> SuperDictateLibraryArchive {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return SuperDictateLibraryArchive()
        }

        try Self.validateExistingRegularFile(fileURL)
        let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
        if let size = (attributes[.size] as? NSNumber)?.intValue,
           size > Self.maximumFileBytes {
            throw SuperDictateLibraryStoreError.fileTooLarge(
                size,
                Self.maximumFileBytes
            )
        }

        let data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
        guard data.count <= Self.maximumFileBytes else {
            throw SuperDictateLibraryStoreError.fileTooLarge(
                data.count,
                Self.maximumFileBytes
            )
        }

        let document = try decoder.decode(SuperDictateLibraryFile.self, from: data)
        guard document.schemaVersion == Self.schemaVersion else {
            throw SuperDictateLibraryStoreError.unsupportedSchema(
                document.schemaVersion
            )
        }
        return try Self.validated(document.archive)
    }

    public func save(_ archive: SuperDictateLibraryArchive) async throws {
        let archive = try Self.validated(archive)
        let document = SuperDictateLibraryFile(
            schemaVersion: Self.schemaVersion,
            updatedAt: Date(),
            archive: archive
        )
        let data = try encoder.encode(document)
        guard data.count <= Self.maximumFileBytes else {
            throw SuperDictateLibraryStoreError.fileTooLarge(
                data.count,
                Self.maximumFileBytes
            )
        }

        try Self.ensurePrivateDirectory(directoryURL, fileManager: fileManager)
        if fileManager.fileExists(atPath: fileURL.path) {
            try Self.validateExistingRegularFile(fileURL)
        }
        try data.write(to: fileURL, options: [.atomic])
        try fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
    }

    public func upsertRecording(
        _ recording: SuperDictateRecording,
        memoryDocument: SuperDictateMemoryDocument? = nil
    ) async throws {
        var archive = try await load()
        if let index = archive.recordings.firstIndex(where: { $0.id == recording.id }) {
            archive.recordings[index] = recording
        } else {
            guard archive.recordings.count < Self.maximumRecordings else {
                throw SuperDictateLibraryStoreError.tooManyRecordings(
                    archive.recordings.count + 1,
                    Self.maximumRecordings
                )
            }
            archive.recordings.append(recording)
        }

        if let memoryDocument {
            guard memoryDocument.recordingID == recording.id else {
                throw SuperDictateLibraryStoreError.duplicateMemoryDocument(
                    memoryDocument.recordingID
                )
            }
            if let index = archive.memoryDocuments.firstIndex(
                where: { $0.recordingID == memoryDocument.recordingID }
            ) {
                archive.memoryDocuments[index] = memoryDocument
            } else {
                guard archive.memoryDocuments.count < Self.maximumMemoryDocuments else {
                    throw SuperDictateLibraryStoreError.tooManyMemoryDocuments(
                        archive.memoryDocuments.count + 1,
                        Self.maximumMemoryDocuments
                    )
                }
                archive.memoryDocuments.append(memoryDocument)
            }
        }
        try await save(archive)
    }

    public func upsertTask(_ task: SuperDictateTask) async throws {
        var archive = try await load()
        if let index = archive.tasks.firstIndex(where: { $0.id == task.id }) {
            archive.tasks[index] = task
        } else {
            guard archive.tasks.count < Self.maximumTasks else {
                throw SuperDictateLibraryStoreError.tooManyTasks(
                    archive.tasks.count + 1,
                    Self.maximumTasks
                )
            }
            archive.tasks.append(task)
        }
        try await save(archive)
    }

    public func removeRecordingFromIndex(_ recordingID: UUID) async throws {
        var archive = try await load()
        let originalRecordingCount = archive.recordings.count
        let originalDocumentCount = archive.memoryDocuments.count
        let originalTaskCount = archive.tasks.count

        archive.recordings.removeAll { $0.id == recordingID }
        archive.memoryDocuments.removeAll { $0.recordingID == recordingID }
        archive.tasks.removeAll { $0.sourceRecordingID == recordingID }

        guard archive.recordings.count != originalRecordingCount
                || archive.memoryDocuments.count != originalDocumentCount
                || archive.tasks.count != originalTaskCount else {
            return
        }
        try await save(archive)
    }

    public func storageURL() -> URL {
        fileURL
    }

    private static func validated(
        _ archive: SuperDictateLibraryArchive
    ) throws -> SuperDictateLibraryArchive {
        guard archive.recordings.count <= maximumRecordings else {
            throw SuperDictateLibraryStoreError.tooManyRecordings(
                archive.recordings.count,
                maximumRecordings
            )
        }
        guard archive.tasks.count <= maximumTasks else {
            throw SuperDictateLibraryStoreError.tooManyTasks(
                archive.tasks.count,
                maximumTasks
            )
        }
        guard archive.memoryDocuments.count <= maximumMemoryDocuments else {
            throw SuperDictateLibraryStoreError.tooManyMemoryDocuments(
                archive.memoryDocuments.count,
                maximumMemoryDocuments
            )
        }

        var recordingIDs: Set<UUID> = []
        for recording in archive.recordings {
            guard recordingIDs.insert(recording.id).inserted else {
                throw SuperDictateLibraryStoreError.duplicateRecording(recording.id)
            }
        }

        var taskIDs: Set<UUID> = []
        for task in archive.tasks {
            guard taskIDs.insert(task.id).inserted else {
                throw SuperDictateLibraryStoreError.duplicateTask(task.id)
            }
        }

        var memoryIDs: Set<UUID> = []
        for document in archive.memoryDocuments {
            guard memoryIDs.insert(document.recordingID).inserted else {
                throw SuperDictateLibraryStoreError.duplicateMemoryDocument(
                    document.recordingID
                )
            }
        }

        return archive
    }

    private static func ensurePrivateDirectory(
        _ url: URL,
        fileManager: FileManager
    ) throws {
        try fileManager.createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try fileManager.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: url.path
        )
    }

    private static func validateExistingRegularFile(_ url: URL) throws {
        let values = try url.resourceValues(
            forKeys: [.isSymbolicLinkKey, .isRegularFileKey]
        )
        guard values.isSymbolicLink != true,
              values.isRegularFile == true else {
            throw SuperDictateLibraryStoreError.unsafeFileType
        }
    }
}
