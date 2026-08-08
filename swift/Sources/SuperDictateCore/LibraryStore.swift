import Darwin
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
    case memoryDocumentRecordingMismatch(recordingID: UUID, documentID: UUID)
    case orphanMemoryDocument(UUID)
    case orphanTaskSource(taskID: UUID, recordingID: UUID)
    case posix(Int32)
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
        SuperDictateProductSnapshot(recordings: recordings, tasks: tasks)
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
/// Authoritative audio/recovery files stay outside this index. Removing a row
/// here never deletes source audio. The index can contain transcript text,
/// people and task metadata, so reads and writes use no-follow POSIX file I/O,
/// private permissions and crash-safe atomic replacement.
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
        directoryURL = rootDirectory.appendingPathComponent("library", isDirectory: true)
        fileURL = directoryURL.appendingPathComponent("index.json", isDirectory: false)
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

        let data = try Self.readPrivateRegularFile(
            fileURL,
            maximumBytes: Self.maximumFileBytes
        )
        let document = try decoder.decode(SuperDictateLibraryFile.self, from: data)
        guard document.schemaVersion == Self.schemaVersion else {
            throw SuperDictateLibraryStoreError.unsupportedSchema(document.schemaVersion)
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
        try Self.atomicPrivateWrite(data, to: fileURL, directoryURL: directoryURL)
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
                throw SuperDictateLibraryStoreError.memoryDocumentRecordingMismatch(
                    recordingID: recording.id,
                    documentID: memoryDocument.recordingID
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
        if let sourceRecordingID = task.sourceRecordingID,
           !archive.recordings.contains(where: { $0.id == sourceRecordingID }) {
            throw SuperDictateLibraryStoreError.orphanTaskSource(
                taskID: task.id,
                recordingID: sourceRecordingID
            )
        }

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
        let previous = (
            archive.recordings.count,
            archive.memoryDocuments.count,
            archive.tasks.count
        )

        archive.recordings.removeAll { $0.id == recordingID }
        archive.memoryDocuments.removeAll { $0.recordingID == recordingID }
        archive.tasks.removeAll { $0.sourceRecordingID == recordingID }

        guard previous != (
            archive.recordings.count,
            archive.memoryDocuments.count,
            archive.tasks.count
        ) else {
            return
        }
        try await save(archive)
    }

    public func storageURL() -> URL { fileURL }

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
            if let sourceRecordingID = task.sourceRecordingID,
               !recordingIDs.contains(sourceRecordingID) {
                throw SuperDictateLibraryStoreError.orphanTaskSource(
                    taskID: task.id,
                    recordingID: sourceRecordingID
                )
            }
        }

        var documentIDs: Set<UUID> = []
        for document in archive.memoryDocuments {
            guard documentIDs.insert(document.recordingID).inserted else {
                throw SuperDictateLibraryStoreError.duplicateMemoryDocument(
                    document.recordingID
                )
            }
            guard recordingIDs.contains(document.recordingID) else {
                throw SuperDictateLibraryStoreError.orphanMemoryDocument(
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

    private static func readPrivateRegularFile(
        _ url: URL,
        maximumBytes: Int
    ) throws -> Data {
        let fd = Darwin.open(url.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
        guard fd >= 0 else {
            if errno == ELOOP { throw SuperDictateLibraryStoreError.unsafeFileType }
            throw SuperDictateLibraryStoreError.posix(errno)
        }
        defer { _ = Darwin.close(fd) }

        var st = stat()
        guard Darwin.fstat(fd, &st) == 0 else {
            throw SuperDictateLibraryStoreError.posix(errno)
        }
        guard (st.st_mode & S_IFMT) == S_IFREG,
              st.st_nlink == 1 else {
            throw SuperDictateLibraryStoreError.unsafeFileType
        }
        guard st.st_size >= 0,
              st.st_size <= off_t(maximumBytes) else {
            throw SuperDictateLibraryStoreError.fileTooLarge(
                Int(max(0, st.st_size)),
                maximumBytes
            )
        }

        var data = Data()
        data.reserveCapacity(Int(st.st_size))
        var buffer = [UInt8](repeating: 0, count: 64 * 1_024)

        while data.count <= maximumBytes {
            let count = buffer.withUnsafeMutableBytes { rawBuffer in
                Darwin.read(fd, rawBuffer.baseAddress, rawBuffer.count)
            }
            if count < 0 {
                if errno == EINTR { continue }
                throw SuperDictateLibraryStoreError.posix(errno)
            }
            guard count > 0 else { break }
            guard data.count + count <= maximumBytes else {
                throw SuperDictateLibraryStoreError.fileTooLarge(
                    data.count + count,
                    maximumBytes
                )
            }
            data.append(contentsOf: buffer.prefix(count))
        }
        return data
    }

    private static func atomicPrivateWrite(
        _ data: Data,
        to targetURL: URL,
        directoryURL: URL
    ) throws {
        if FileManager.default.fileExists(atPath: targetURL.path) {
            let fd = Darwin.open(targetURL.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
            guard fd >= 0 else {
                if errno == ELOOP { throw SuperDictateLibraryStoreError.unsafeFileType }
                throw SuperDictateLibraryStoreError.posix(errno)
            }
            var st = stat()
            let statSucceeded = Darwin.fstat(fd, &st) == 0
            let statErrno = errno
            _ = Darwin.close(fd)
            guard statSucceeded else {
                throw SuperDictateLibraryStoreError.posix(statErrno)
            }
            guard (st.st_mode & S_IFMT) == S_IFREG,
                  st.st_nlink == 1 else {
                throw SuperDictateLibraryStoreError.unsafeFileType
            }
        }

        let tempURL = directoryURL.appendingPathComponent(
            ".index.\(UUID().uuidString).tmp",
            isDirectory: false
        )
        let fd = Darwin.open(
            tempURL.path,
            O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
            mode_t(0o600)
        )
        guard fd >= 0 else {
            throw SuperDictateLibraryStoreError.posix(errno)
        }

        var closeNeeded = true
        defer {
            if closeNeeded { _ = Darwin.close(fd) }
            _ = Darwin.unlink(tempURL.path)
        }

        try data.withUnsafeBytes { rawBuffer in
            var offset = 0
            while offset < rawBuffer.count {
                let written = Darwin.write(
                    fd,
                    rawBuffer.baseAddress!.advanced(by: offset),
                    rawBuffer.count - offset
                )
                if written < 0 {
                    if errno == EINTR { continue }
                    throw SuperDictateLibraryStoreError.posix(errno)
                }
                guard written > 0 else {
                    throw SuperDictateLibraryStoreError.posix(EIO)
                }
                offset += written
            }
        }

        guard Darwin.fsync(fd) == 0 else {
            throw SuperDictateLibraryStoreError.posix(errno)
        }
        guard Darwin.close(fd) == 0 else {
            closeNeeded = false
            throw SuperDictateLibraryStoreError.posix(errno)
        }
        closeNeeded = false

        guard Darwin.rename(tempURL.path, targetURL.path) == 0 else {
            throw SuperDictateLibraryStoreError.posix(errno)
        }
        guard Darwin.chmod(targetURL.path, mode_t(0o600)) == 0 else {
            throw SuperDictateLibraryStoreError.posix(errno)
        }

        let directoryFD = Darwin.open(directoryURL.path, O_RDONLY | O_CLOEXEC)
        if directoryFD >= 0 {
            _ = Darwin.fsync(directoryFD)
            _ = Darwin.close(directoryFD)
        }
    }
}
