import Foundation
import XCTest
@testable import SuperDictateCore

final class ProductLibraryStoreTests: XCTestCase {
    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("superdictate-library-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }

    private func item(
        id: UUID = UUID(),
        title: String,
        createdAt: TimeInterval
    ) -> SuperDictateLibraryItem {
        SuperDictateLibraryItem(
            id: id,
            title: title,
            createdAt: Date(timeIntervalSince1970: createdAt),
            durationMilliseconds: 2_000,
            previewText: "Private transcript preview for \(title)",
            people: ["Alice"],
            tags: ["Client"],
            state: .ready,
            taskCount: 1,
            hasTranscript: true
        )
    }

    func testMissingIndexLoadsAsEmptySnapshot() async throws {
        let store = try JSONSuperDictateLibraryStore(
            rootDirectory: temporaryDirectory()
        )

        let snapshot = try await store.load()

        XCTAssertTrue(snapshot.items.isEmpty)
    }

    func testRoundTripAndUpsertPreserveStableIdentity() async throws {
        let id = UUID()
        let store = try JSONSuperDictateLibraryStore(
            rootDirectory: temporaryDirectory()
        )
        try await store.upsert(item(id: id, title: "First title", createdAt: 10))
        try await store.upsert(item(id: id, title: "Updated title", createdAt: 20))
        try await store.upsert(item(title: "Second recording", createdAt: 30))

        let snapshot = try await store.load()

        XCTAssertEqual(snapshot.items.count, 2)
        XCTAssertEqual(snapshot.items.first { $0.id == id }?.title, "Updated title")
        XCTAssertEqual(snapshot.results().first?.title, "Second recording")
    }

    func testRemoveOnlyDeletesRequestedProjection() async throws {
        let firstID = UUID()
        let secondID = UUID()
        let store = try JSONSuperDictateLibraryStore(
            rootDirectory: temporaryDirectory()
        )
        try await store.save(
            SuperDictateLibrarySnapshot(items: [
                item(id: firstID, title: "First", createdAt: 10),
                item(id: secondID, title: "Second", createdAt: 20),
            ])
        )

        try await store.remove(recordingID: firstID)
        let snapshot = try await store.load()

        XCTAssertEqual(snapshot.items.map(\.id), [secondID])
    }

    func testDuplicateIdentityIsRejectedInsteadOfSilentlyCollapsing() async throws {
        let id = UUID()
        let store = try JSONSuperDictateLibraryStore(
            rootDirectory: temporaryDirectory()
        )

        do {
            try await store.save(
                SuperDictateLibrarySnapshot(items: [
                    item(id: id, title: "First", createdAt: 10),
                    item(id: id, title: "Duplicate", createdAt: 20),
                ])
            )
            XCTFail("Expected duplicate identity rejection")
        } catch let error as SuperDictateLibraryStoreError {
            XCTAssertEqual(error, .duplicateIdentity(id))
        }
    }

    func testUnsupportedSchemaIsRejected() async throws {
        let root = try temporaryDirectory()
        let store = try JSONSuperDictateLibraryStore(rootDirectory: root)
        let url = await store.storageURL()
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let invalid = Data("{\"schemaVersion\":999,\"updatedAt\":0,\"items\":[]}".utf8)
        try invalid.write(to: url)

        do {
            _ = try await store.load()
            XCTFail("Expected unsupported schema")
        } catch let error as SuperDictateLibraryStoreError {
            XCTAssertEqual(error, .unsupportedSchema(999))
        }
    }

    func testOversizedIndexIsRejectedBeforeDecode() async throws {
        let root = try temporaryDirectory()
        let store = try JSONSuperDictateLibraryStore(rootDirectory: root)
        let url = await store.storageURL()
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(
            repeating: 0x20,
            count: JSONSuperDictateLibraryStore.maximumFileBytes + 1
        ).write(to: url)

        do {
            _ = try await store.load()
            XCTFail("Expected oversized index rejection")
        } catch let error as SuperDictateLibraryStoreError {
            guard case .fileTooLarge(let actual, let limit) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertGreaterThan(actual, limit)
            XCTAssertEqual(limit, JSONSuperDictateLibraryStore.maximumFileBytes)
        }
    }

    #if os(macOS)
    func testLibraryDirectoryAndIndexUsePrivatePOSIXPermissions() async throws {
        let root = try temporaryDirectory()
        let store = try JSONSuperDictateLibraryStore(rootDirectory: root)
        try await store.upsert(item(title: "Private", createdAt: 10))
        let indexURL = await store.storageURL()
        let directoryURL = indexURL.deletingLastPathComponent()

        let filePermissions = try XCTUnwrap(
            FileManager.default.attributesOfItem(atPath: indexURL.path)[.posixPermissions] as? NSNumber
        ).intValue
        let directoryPermissions = try XCTUnwrap(
            FileManager.default.attributesOfItem(atPath: directoryURL.path)[.posixPermissions] as? NSNumber
        ).intValue

        XCTAssertEqual(filePermissions & 0o777, 0o600)
        XCTAssertEqual(directoryPermissions & 0o777, 0o700)
    }
    #endif
}
