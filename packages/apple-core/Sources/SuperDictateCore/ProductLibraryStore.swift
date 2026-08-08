import Foundation

public enum SuperDictateLibraryStoreError: Error, Equatable, Sendable {
    case unsupportedSchema(Int)
    case fileTooLarge(Int, Int)
    case tooManyItems(Int, Int)
    case duplicateIdentity(UUID)
}

public protocol SuperDictateLibraryStoring: Sendable {
    func load() async throws -> SuperDictateLibrarySnapshot
    func save(_ snapshot: SuperDictateLibrarySnapshot) async throws
    func upsert(_ item: SuperDictateLibraryItem) async throws
    func remove(recordingID: UUID) async throws
}

private struct SuperDictateLibraryDocument: Codable, Sendable {
    let schemaVersion: Int
    let updatedAt: Date
    let items: [SuperDictateLibraryItem]
}

/// Small local projection store for fast Today/Library startup.
///
/// This file is not the authoritative audio/transcript source. Recording
/// packages and manifests remain authoritative. The index can therefore be
/// rebuilt if needed, but while present it must still be treated as private
/// user data because it may contain transcript previews, people and tags.
public actor JSONSuperDictateLibraryStore: SuperDictateLibraryStoring {
    public static let schemaVersion = 1
    public static let maximumFileBytes = 32 * 1_024 * 1_024
    public static let maximumItems = 50_000

    private let directoryURL: URL
    private let indexURL: URL
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
        self.indexURL = directoryURL.appendingPathComponent(
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

    public func load() async throws -> SuperDictateLibrarySnapshot {
        guard fileManager.fileExists(atPath: indexURL.path) else {
            return SuperDictateLibrarySnapshot()
        }

        let attributes = try fileManager.attributesOfItem(atPath: indexURL.path)
        if let size = (attributes[.size] as? NSNumber)?.intValue,
           size > Self.maximumFileBytes {
            throw SuperDictateLibraryStoreError.fileTooLarge(
                size,
                Self.maximumFileBytes
            )
        }

        let data = try Data(contentsOf: indexURL)
        guard data.count <= Self.maximumFileBytes else {
            throw SuperDictateLibraryStoreError.fileTooLarge(
                data.count,
                Self.maximumFileBytes
            )
        }
        let document = try decoder.decode(
            SuperDictateLibraryDocument.self,
            from: data
        )
        guard document.schemaVersion == Self.schemaVersion else {
            throw SuperDictateLibraryStoreError.unsupportedSchema(
                document.schemaVersion
            )
        }
        return try Self.validatedSnapshot(document.items)
    }

    public func save(_ snapshot: SuperDictateLibrarySnapshot) async throws {
        let validated = try Self.validatedSnapshot(snapshot.items)
        let document = SuperDictateLibraryDocument(
            schemaVersion: Self.schemaVersion,
            updatedAt: Date(),
            items: validated.items
        )
        let data = try encoder.encode(document)
        guard data.count <= Self.maximumFileBytes else {
            throw SuperDictateLibraryStoreError.fileTooLarge(
                data.count,
                Self.maximumFileBytes
            )
        }

        try Self.ensurePrivateDirectory(directoryURL, fileManager: fileManager)
        try data.write(to: indexURL, options: [.atomic])
        try fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: indexURL.path
        )
    }

    public func upsert(_ item: SuperDictateLibraryItem) async throws {
        var snapshot = try await load()
        if let index = snapshot.items.firstIndex(where: { $0.id == item.id }) {
            snapshot.items[index] = item
        } else {
            guard snapshot.items.count < Self.maximumItems else {
                throw SuperDictateLibraryStoreError.tooManyItems(
                    snapshot.items.count + 1,
                    Self.maximumItems
                )
            }
            snapshot.items.append(item)
        }
        try await save(snapshot)
    }

    public func remove(recordingID: UUID) async throws {
        var snapshot = try await load()
        let originalCount = snapshot.items.count
        snapshot.items.removeAll { $0.id == recordingID }
        guard snapshot.items.count != originalCount else { return }
        try await save(snapshot)
    }

    public func storageURL() -> URL {
        indexURL
    }

    private static func validatedSnapshot(
        _ items: [SuperDictateLibraryItem]
    ) throws -> SuperDictateLibrarySnapshot {
        guard items.count <= maximumItems else {
            throw SuperDictateLibraryStoreError.tooManyItems(
                items.count,
                maximumItems
            )
        }

        var seen: Set<UUID> = []
        for item in items {
            guard seen.insert(item.id).inserted else {
                throw SuperDictateLibraryStoreError.duplicateIdentity(item.id)
            }
        }
        return SuperDictateLibrarySnapshot(items: items)
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
}
