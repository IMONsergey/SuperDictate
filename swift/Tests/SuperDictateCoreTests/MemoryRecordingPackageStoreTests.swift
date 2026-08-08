import Foundation
import XCTest
@testable import SuperDictateCore

extension ProductStateTests {
    private func withMemoryPackageStore<T>(
        _ body: (URL, JSONSuperDictateMemoryPackageStore) async throws -> T
    ) async throws -> T {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateMemoryPackageTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        return try await body(root, store)
    }

    func testMemoryPackageCreateAndLoadRoundTripUsesPrivatePermissions() async throws {
        try await withMemoryPackageStore { _, store in
            let id = UUID()
            let createdAt = Date(timeIntervalSince1970: 1_700_000_123)
            let created = try await store.createPackage(recordingID: id, createdAt: createdAt)
            let loaded = try await store.loadManifest(recordingID: id)

            XCTAssertEqual(loaded, created)
            XCTAssertEqual(created.recordingID, id)
            XCTAssertEqual(created.createdAt, createdAt)
            XCTAssertEqual(created.state, .recording)

            let packageURL = await store.packageURL(recordingID: id)
            let manifestURL = await store.manifestURL(recordingID: id)
            let packageAttributes = try FileManager.default.attributesOfItem(atPath: packageURL.path)
            let manifestAttributes = try FileManager.default.attributesOfItem(atPath: manifestURL.path)
            XCTAssertEqual((packageAttributes[.posixPermissions] as? NSNumber)?.intValue, 0o700)
            XCTAssertEqual((manifestAttributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
        }
    }

    func testMemoryPackageManifestSavePreservesValidatedDualTrackChunks() async throws {
        try await withMemoryPackageStore { _, store in
            let id = UUID()
            var manifest = try await store.createPackage(recordingID: id)
            let microphone = try SuperDictateMemoryAudioChunk(
                source: .microphone,
                sequence: 0,
                relativePath: "audio/microphone/000000.caf",
                sessionStartMilliseconds: 0,
                sessionEndMilliseconds: 2_000,
                sampleRate: 48_000,
                channelCount: 1,
                byteLength: 10_000,
                sha256: String(repeating: "a", count: 64)
            )
            let system = try SuperDictateMemoryAudioChunk(
                source: .system,
                sequence: 0,
                relativePath: "audio/system/000000.caf",
                sessionStartMilliseconds: 120,
                sessionEndMilliseconds: 2_120,
                sampleRate: 48_000,
                channelCount: 2,
                byteLength: 20_000,
                sha256: String(repeating: "b", count: 64)
            )
            try manifest.appendFinalizedChunk(microphone)
            try manifest.appendFinalizedChunk(system)
            manifest.state = .ready

            try await store.saveManifest(manifest)
            let maybeLoaded = try await store.loadManifest(recordingID: id)
            let loaded = try XCTUnwrap(maybeLoaded)
            XCTAssertEqual(loaded, manifest)
            XCTAssertEqual(loaded.chunks(for: .microphone), [microphone])
            XCTAssertEqual(loaded.chunks(for: .system), [system])
        }
    }

    func testMemoryPackageCreationIsExclusive() async throws {
        try await withMemoryPackageStore { _, store in
            let id = UUID()
            _ = try await store.createPackage(recordingID: id)

            do {
                _ = try await store.createPackage(recordingID: id)
                XCTFail("duplicate package creation should fail")
            } catch {
                XCTAssertEqual(
                    error as? SuperDictateMemoryPackageStoreError,
                    .packageAlreadyExists(id)
                )
            }
        }
    }

    func testSymlinkPackageIsNeverTreatedAsRecoveryTarget() async throws {
        try await withMemoryPackageStore { root, store in
            let id = UUID()
            let outside = root.appendingPathComponent("outside", isDirectory: true)
            try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)

            let packageURL = await store.packageURL(recordingID: id)
            try FileManager.default.createSymbolicLink(at: packageURL, withDestinationURL: outside)

            let ids = try await store.existingRecordingIDs()
            XCTAssertFalse(ids.contains(id))

            do {
                _ = try await store.loadManifest(recordingID: id)
                XCTFail("symlink package should be rejected")
            } catch {
                XCTAssertEqual(error as? SuperDictateMemoryPackageStoreError, .unsafeFileType)
            }
        }
    }

    func testSymlinkManifestIsRejectedWithoutFollowingTarget() async throws {
        try await withMemoryPackageStore { root, store in
            let id = UUID()
            _ = try await store.createPackage(recordingID: id)
            let manifestURL = await store.manifestURL(recordingID: id)
            try FileManager.default.removeItem(at: manifestURL)

            let outside = root.appendingPathComponent("outside.json")
            try Data("{}".utf8).write(to: outside)
            try FileManager.default.createSymbolicLink(at: manifestURL, withDestinationURL: outside)

            do {
                _ = try await store.loadManifest(recordingID: id)
                XCTFail("symlink manifest should be rejected")
            } catch {
                XCTAssertEqual(error as? SuperDictateMemoryPackageStoreError, .unsafeFileType)
            }
        }
    }

    func testManifestCannotBeCopiedAcrossRecordingPackages() async throws {
        try await withMemoryPackageStore { _, store in
            let firstID = UUID()
            let secondID = UUID()
            _ = try await store.createPackage(recordingID: firstID)
            _ = try await store.createPackage(recordingID: secondID)

            let firstURL = await store.manifestURL(recordingID: firstID)
            let secondURL = await store.manifestURL(recordingID: secondID)
            let firstBytes = try Data(contentsOf: firstURL)
            try firstBytes.write(to: secondURL, options: .atomic)

            do {
                _ = try await store.loadManifest(recordingID: secondID)
                XCTFail("a manifest must be bound to its package recording ID")
            } catch {
                XCTAssertEqual(
                    error as? SuperDictateMemoryPackageStoreError,
                    .manifestRecordingMismatch(expected: secondID, actual: firstID)
                )
            }
        }
    }
}
