import Darwin
import Foundation

public enum SuperDictateMemoryPackageStoreError: Error, Equatable, Sendable {
    case packageAlreadyExists(UUID)
    case packageMissing(UUID)
    case manifestMissing(UUID)
    case manifestRecordingMismatch(expected: UUID, actual: UUID)
    case unsupportedSchema(Int)
    case unsafeFileType
    case fileTooLarge(Int, Int)
    case posix(Int32)
}

private struct SuperDictateMemoryManifestFile: Codable, Sendable {
    let schemaVersion: Int
    let updatedAt: Date
    let manifest: SuperDictateMemoryRecordingManifest
}

public actor JSONSuperDictateMemoryPackageStore {
    public static let schemaVersion = 1
    public static let maximumManifestBytes = 4 * 1_024 * 1_024

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
        recordingsDirectory = rootDirectory.appendingPathComponent(
            "memory-recordings",
            isDirectory: true
        )
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        self.decoder = decoder

        try Self.ensurePrivateDirectory(rootDirectory, fileManager: fileManager)
        try Self.ensurePrivateDirectory(recordingsDirectory, fileManager: fileManager)
    }

    @discardableResult
    public func createPackage(
        recordingID: UUID = UUID(),
        createdAt: Date = Date()
    ) throws -> SuperDictateMemoryRecordingManifest {
        let packageURL = packageURL(recordingID: recordingID)
        do {
            try Self.createPrivateDirectoryExclusively(packageURL)
        } catch SuperDictateMemoryPackageStoreError.posix(let code) where code == EEXIST {
            throw SuperDictateMemoryPackageStoreError.packageAlreadyExists(recordingID)
        }

        do {
            // Make the package-directory creation durable before we begin adding
            // child state. After a crash the parent must either know the package
            // exists or not; a successful create must never rely on cache only.
            try Self.synchronizeDirectory(recordingsDirectory)

            let audioRoot = packageURL.appendingPathComponent("audio", isDirectory: true)
            try Self.createPrivateDirectoryExclusively(audioRoot)
            for source in SuperDictateMemoryAudioSource.allCases {
                try Self.createPrivateDirectoryExclusively(
                    audioDirectory(recordingID: recordingID, source: source)
                )
            }
            try Self.createPrivateDirectoryExclusively(
                quarantineDirectory(recordingID: recordingID)
            )
            try Self.synchronizeDirectory(audioRoot)
            try Self.synchronizeDirectory(packageURL)

            let manifest = try SuperDictateMemoryRecordingManifest(
                recordingID: recordingID,
                createdAt: createdAt
            )
            try writeManifest(manifest, requireExistingPackage: true)
            return manifest
        } catch {
            try? fileManager.removeItem(at: packageURL)
            try? Self.synchronizeDirectory(recordingsDirectory)
            throw error
        }
    }

    public func loadManifest(
        recordingID: UUID
    ) throws -> SuperDictateMemoryRecordingManifest? {
        let packageURL = packageURL(recordingID: recordingID)
        switch try Self.pathKind(packageURL) {
        case .missing:
            return nil
        case .directory:
            break
        case .regularFile, .other:
            throw SuperDictateMemoryPackageStoreError.unsafeFileType
        }

        let url = manifestURL(recordingID: recordingID)
        switch try Self.pathKind(url) {
        case .missing:
            throw SuperDictateMemoryPackageStoreError.manifestMissing(recordingID)
        case .regularFile:
            break
        case .directory, .other:
            throw SuperDictateMemoryPackageStoreError.unsafeFileType
        }

        let data = try Self.readPrivateRegularFile(
            url,
            maximumBytes: Self.maximumManifestBytes
        )
        let file = try decoder.decode(SuperDictateMemoryManifestFile.self, from: data)
        guard file.schemaVersion == Self.schemaVersion else {
            throw SuperDictateMemoryPackageStoreError.unsupportedSchema(file.schemaVersion)
        }
        guard file.manifest.recordingID == recordingID else {
            throw SuperDictateMemoryPackageStoreError.manifestRecordingMismatch(
                expected: recordingID,
                actual: file.manifest.recordingID
            )
        }
        try file.manifest.validate()
        return file.manifest
    }

    /// Internal on purpose. External capture adapters must mutate manifests only
    /// through actor-isolated package operations so microphone and system writers
    /// cannot race a load-modify-save cycle.
    func saveManifest(_ manifest: SuperDictateMemoryRecordingManifest) throws {
        try manifest.validate()
        try writeManifest(manifest, requireExistingPackage: true)
    }

    public func existingRecordingIDs() throws -> [UUID] {
        try Self.validatePrivateDirectory(recordingsDirectory)
        let names = try fileManager.contentsOfDirectory(atPath: recordingsDirectory.path)
        var ids: [UUID] = []
        for name in names {
            guard let id = UUID(uuidString: name) else { continue }
            let url = recordingsDirectory.appendingPathComponent(name, isDirectory: true)
            do {
                try Self.validatePrivateDirectory(url)
                ids.append(id)
            } catch SuperDictateMemoryPackageStoreError.unsafeFileType {
                continue
            }
        }
        return ids.sorted { $0.uuidString < $1.uuidString }
    }

    public func packageURL(recordingID: UUID) -> URL {
        recordingsDirectory.appendingPathComponent(
            recordingID.uuidString.lowercased(),
            isDirectory: true
        )
    }

    public func manifestURL(recordingID: UUID) -> URL {
        packageURL(recordingID: recordingID)
            .appendingPathComponent("manifest.json", isDirectory: false)
    }

    public func audioDirectory(
        recordingID: UUID,
        source: SuperDictateMemoryAudioSource
    ) -> URL {
        packageURL(recordingID: recordingID)
            .appendingPathComponent("audio", isDirectory: true)
            .appendingPathComponent(source.rawValue, isDirectory: true)
    }

    public func quarantineDirectory(recordingID: UUID) -> URL {
        packageURL(recordingID: recordingID)
            .appendingPathComponent("quarantine", isDirectory: true)
    }

    private func writeManifest(
        _ manifest: SuperDictateMemoryRecordingManifest,
        requireExistingPackage: Bool
    ) throws {
        let packageURL = packageURL(recordingID: manifest.recordingID)
        if requireExistingPackage {
            switch try Self.pathKind(packageURL) {
            case .directory:
                break
            case .missing:
                throw SuperDictateMemoryPackageStoreError.packageMissing(manifest.recordingID)
            case .regularFile, .other:
                throw SuperDictateMemoryPackageStoreError.unsafeFileType
            }
        }

        let file = SuperDictateMemoryManifestFile(
            schemaVersion: Self.schemaVersion,
            updatedAt: Date(),
            manifest: manifest
        )
        let data = try encoder.encode(file)
        guard data.count <= Self.maximumManifestBytes else {
            throw SuperDictateMemoryPackageStoreError.fileTooLarge(
                data.count,
                Self.maximumManifestBytes
            )
        }
        try Self.atomicPrivateWrite(
            data,
            to: manifestURL(recordingID: manifest.recordingID),
            directoryURL: packageURL
        )
    }

    private enum PathKind {
        case missing
        case regularFile
        case directory
        case other
    }

    private static func pathKind(_ url: URL) throws -> PathKind {
        var st = stat()
        if Darwin.lstat(url.path, &st) != 0 {
            if errno == ENOENT { return .missing }
            throw SuperDictateMemoryPackageStoreError.posix(errno)
        }
        switch st.st_mode & S_IFMT {
        case S_IFREG:
            return st.st_nlink == 1 ? .regularFile : .other
        case S_IFDIR:
            return .directory
        default:
            return .other
        }
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
        try validatePrivateDirectory(url)
        guard Darwin.chmod(url.path, mode_t(0o700)) == 0 else {
            throw SuperDictateMemoryPackageStoreError.posix(errno)
        }
    }

    private static func createPrivateDirectoryExclusively(_ url: URL) throws {
        guard Darwin.mkdir(url.path, mode_t(0o700)) == 0 else {
            throw SuperDictateMemoryPackageStoreError.posix(errno)
        }
        try validatePrivateDirectory(url)
    }

    private static func validatePrivateDirectory(_ url: URL) throws {
        guard try pathKind(url) == .directory else {
            throw SuperDictateMemoryPackageStoreError.unsafeFileType
        }
    }

    private static func readPrivateRegularFile(
        _ url: URL,
        maximumBytes: Int
    ) throws -> Data {
        let fd = Darwin.open(url.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
        guard fd >= 0 else {
            if errno == ELOOP { throw SuperDictateMemoryPackageStoreError.unsafeFileType }
            throw SuperDictateMemoryPackageStoreError.posix(errno)
        }
        defer { _ = Darwin.close(fd) }

        var st = stat()
        guard Darwin.fstat(fd, &st) == 0 else {
            throw SuperDictateMemoryPackageStoreError.posix(errno)
        }
        guard (st.st_mode & S_IFMT) == S_IFREG,
              st.st_nlink == 1 else {
            throw SuperDictateMemoryPackageStoreError.unsafeFileType
        }
        guard st.st_size >= 0,
              st.st_size <= off_t(maximumBytes) else {
            throw SuperDictateMemoryPackageStoreError.fileTooLarge(
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
                throw SuperDictateMemoryPackageStoreError.posix(errno)
            }
            guard count > 0 else { break }
            guard data.count + count <= maximumBytes else {
                throw SuperDictateMemoryPackageStoreError.fileTooLarge(
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
        try validatePrivateDirectory(directoryURL)
        switch try pathKind(targetURL) {
        case .missing:
            break
        case .regularFile:
            break
        case .directory, .other:
            throw SuperDictateMemoryPackageStoreError.unsafeFileType
        }

        let tempURL = directoryURL.appendingPathComponent(
            ".manifest.\(UUID().uuidString).tmp",
            isDirectory: false
        )
        let fd = Darwin.open(
            tempURL.path,
            O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
            mode_t(0o600)
        )
        guard fd >= 0 else {
            throw SuperDictateMemoryPackageStoreError.posix(errno)
        }

        var closeNeeded = true
        defer {
            if closeNeeded { _ = Darwin.close(fd) }
            _ = Darwin.unlink(tempURL.path)
        }

        try data.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else { return }
            var offset = 0
            while offset < bytes.count {
                let written = Darwin.write(
                    fd,
                    baseAddress.advanced(by: offset),
                    bytes.count - offset
                )
                if written < 0 {
                    if errno == EINTR { continue }
                    throw SuperDictateMemoryPackageStoreError.posix(errno)
                }
                guard written > 0 else {
                    throw SuperDictateMemoryPackageStoreError.posix(EIO)
                }
                offset += written
            }
        }

        guard Darwin.fchmod(fd, mode_t(0o600)) == 0 else {
            throw SuperDictateMemoryPackageStoreError.posix(errno)
        }
        guard Darwin.fsync(fd) == 0 else {
            throw SuperDictateMemoryPackageStoreError.posix(errno)
        }
        guard Darwin.close(fd) == 0 else {
            closeNeeded = false
            throw SuperDictateMemoryPackageStoreError.posix(errno)
        }
        closeNeeded = false

        guard Darwin.rename(tempURL.path, targetURL.path) == 0 else {
            throw SuperDictateMemoryPackageStoreError.posix(errno)
        }
        guard Darwin.chmod(targetURL.path, mode_t(0o600)) == 0 else {
            throw SuperDictateMemoryPackageStoreError.posix(errno)
        }
        try synchronizeDirectory(directoryURL)
    }

    private static func synchronizeDirectory(_ directoryURL: URL) throws {
        let fd = Darwin.open(
            directoryURL.path,
            O_RDONLY | O_CLOEXEC | O_NOFOLLOW
        )
        guard fd >= 0 else {
            if errno == ELOOP {
                throw SuperDictateMemoryPackageStoreError.unsafeFileType
            }
            throw SuperDictateMemoryPackageStoreError.posix(errno)
        }
        defer { _ = Darwin.close(fd) }

        var st = stat()
        guard Darwin.fstat(fd, &st) == 0 else {
            throw SuperDictateMemoryPackageStoreError.posix(errno)
        }
        guard (st.st_mode & S_IFMT) == S_IFDIR else {
            throw SuperDictateMemoryPackageStoreError.unsafeFileType
        }
        guard Darwin.fsync(fd) == 0 else {
            throw SuperDictateMemoryPackageStoreError.posix(errno)
        }
    }
}
