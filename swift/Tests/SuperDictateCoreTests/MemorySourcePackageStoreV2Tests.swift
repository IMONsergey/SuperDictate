import Foundation
import XCTest
@testable import SuperDictateCore

extension ProductStateTests {
    private func withMemorySourceStoreV2<T>(
        _ body: (URL, JSONSuperDictateMemoryPackageStore) async throws -> T
    ) async throws -> T {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateSourceStoreV2-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        return try await body(root, store)
    }

    private func packageV2Chunk(
        source: SuperDictateMemoryAudioSource,
        sequence: Int,
        id: UUID = UUID()
    ) throws -> SuperDictateMemoryAudioChunk {
        try SuperDictateMemoryAudioChunk(
            id: id,
            source: source,
            sequence: sequence,
            relativePath: SuperDictateMemoryAudioChunk.canonicalRelativePath(
                source: source,
                sequence: sequence,
                chunkID: id
            ),
            sessionStartMilliseconds: Int64(sequence) * 1_000,
            sessionEndMilliseconds: Int64(sequence + 1) * 1_000,
            sampleRate: 48_000,
            channelCount: source == .system ? 2 : 1,
            byteLength: 1_024,
            sha256: String(repeating: source == .system ? "b" : "a", count: 64)
        )
    }

    func testPackageRoundTripUsesPrivatePermissions() async throws {
        try await withMemorySourceStoreV2 { _, store in
            let id = UUID()
            let created = try await store.createPackage(
                recordingID: id,
                createdAt: Date(timeIntervalSince1970: 100)
            )
            let loaded = try await store.loadManifest(recordingID: id)
            XCTAssertEqual(loaded, created)

            let packageURL = await store.packageURL(recordingID: id)
            let manifestURL = await store.manifestURL(recordingID: id)
            let packageAttrs = try FileManager.default.attributesOfItem(atPath: packageURL.path)
            let manifestAttrs = try FileManager.default.attributesOfItem(atPath: manifestURL.path)
            XCTAssertEqual((packageAttrs[.posixPermissions] as? NSNumber)?.intValue, 0o700)
            XCTAssertEqual((manifestAttrs[.posixPermissions] as? NSNumber)?.intValue, 0o600)
        }
    }

    func testPackageCreationIsExclusive() async throws {
        try await withMemorySourceStoreV2 { _, store in
            let id = UUID()
            _ = try await store.createPackage(recordingID: id)
            do {
                _ = try await store.createPackage(recordingID: id)
                XCTFail("duplicate package creation must fail")
            } catch {
                XCTAssertEqual(
                    error as? SuperDictateMemoryPackageStoreError,
                    .packageAlreadyExists(id)
                )
            }
        }
    }

    func testPackageAndManifestSymlinksAreNeverFollowed() async throws {
        try await withMemorySourceStoreV2 { root, store in
            let packageSymlinkID = UUID()
            let outsideDirectory = root.appendingPathComponent("outside", isDirectory: true)
            try FileManager.default.createDirectory(at: outsideDirectory, withIntermediateDirectories: true)
            let packageURL = await store.packageURL(recordingID: packageSymlinkID)
            try FileManager.default.createSymbolicLink(
                at: packageURL,
                withDestinationURL: outsideDirectory
            )
            do {
                _ = try await store.loadManifest(recordingID: packageSymlinkID)
                XCTFail("package symlink must be unsafe")
            } catch {
                XCTAssertEqual(error as? SuperDictateMemoryPackageStoreError, .unsafeFileType)
            }

            let manifestSymlinkID = UUID()
            _ = try await store.createPackage(recordingID: manifestSymlinkID)
            let manifestURL = await store.manifestURL(recordingID: manifestSymlinkID)
            try FileManager.default.removeItem(at: manifestURL)
            let outsideFile = root.appendingPathComponent("outside.json")
            try Data("{}".utf8).write(to: outsideFile)
            try FileManager.default.createSymbolicLink(
                at: manifestURL,
                withDestinationURL: outsideFile
            )
            do {
                _ = try await store.loadManifest(recordingID: manifestSymlinkID)
                XCTFail("manifest symlink must be unsafe")
            } catch {
                XCTAssertEqual(error as? SuperDictateMemoryPackageStoreError, .unsafeFileType)
            }
        }
    }

    func testBrokenSymlinksAreUnsafeNotMissing() async throws {
        try await withMemorySourceStoreV2 { root, store in
            let packageID = UUID()
            let packageURL = await store.packageURL(recordingID: packageID)
            try FileManager.default.createSymbolicLink(
                at: packageURL,
                withDestinationURL: root.appendingPathComponent("does-not-exist")
            )
            do {
                _ = try await store.loadManifest(recordingID: packageID)
                XCTFail("broken package symlink must remain observable as unsafe")
            } catch {
                XCTAssertEqual(error as? SuperDictateMemoryPackageStoreError, .unsafeFileType)
            }

            let manifestID = UUID()
            _ = try await store.createPackage(recordingID: manifestID)
            let manifestURL = await store.manifestURL(recordingID: manifestID)
            try FileManager.default.removeItem(at: manifestURL)
            try FileManager.default.createSymbolicLink(
                at: manifestURL,
                withDestinationURL: root.appendingPathComponent("missing-manifest-target")
            )
            do {
                _ = try await store.loadManifest(recordingID: manifestID)
                XCTFail("broken manifest symlink must remain observable as unsafe")
            } catch {
                XCTAssertEqual(error as? SuperDictateMemoryPackageStoreError, .unsafeFileType)
            }
        }
    }

    func testManifestIsBoundToItsPackageRecordingID() async throws {
        try await withMemorySourceStoreV2 { _, store in
            let first = UUID()
            let second = UUID()
            _ = try await store.createPackage(recordingID: first)
            _ = try await store.createPackage(recordingID: second)

            let firstURL = await store.manifestURL(recordingID: first)
            let secondURL = await store.manifestURL(recordingID: second)
            let bytes = try Data(contentsOf: firstURL)
            try bytes.write(to: secondURL)

            do {
                _ = try await store.loadManifest(recordingID: second)
                XCTFail("copied manifest must not change package identity")
            } catch {
                XCTAssertEqual(
                    error as? SuperDictateMemoryPackageStoreError,
                    .manifestRecordingMismatch(expected: second, actual: first)
                )
            }
        }
    }

    func testConcurrentMicrophoneAndSystemMutationsDoNotLoseEitherChunk() async throws {
        try await withMemorySourceStoreV2 { _, store in
            let recordingID = UUID()
            _ = try await store.createPackage(recordingID: recordingID)
            let microphone = try packageV2Chunk(source: .microphone, sequence: 0)
            let system = try packageV2Chunk(source: .system, sequence: 0)

            async let micWrite = store.appendFinalizedChunk(
                recordingID: recordingID,
                chunk: microphone
            )
            async let systemWrite = store.appendFinalizedChunk(
                recordingID: recordingID,
                chunk: system
            )
            _ = try await (micWrite, systemWrite)

            let maybeManifest = try await store.loadManifest(recordingID: recordingID)
            let manifest = try XCTUnwrap(maybeManifest)
            XCTAssertEqual(Set(manifest.chunks.map(\.id)), Set([microphone.id, system.id]))
            XCTAssertEqual(manifest.chunks(for: .microphone), [microphone])
            XCTAssertEqual(manifest.chunks(for: .system), [system])
        }
    }
}
