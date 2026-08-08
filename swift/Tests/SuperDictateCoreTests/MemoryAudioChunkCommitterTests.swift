import CryptoKit
import Foundation
import XCTest
@testable import SuperDictateCore

extension ProductStateTests {
    private func cafTestBytes(_ payload: String = "audio-payload") -> Data {
        var data = Data("caff".utf8)
        data.append(Data(payload.utf8))
        return data
    }

    private func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    func testMemoryChunkCommitFinalizesHashesAndAppendsManifest() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateChunkCommit-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)
        let committer = SuperDictateMemoryAudioChunkCommitter(store: store)
        let chunkID = UUID()
        let temporaryURL = try await committer.temporaryChunkURL(
            recordingID: recordingID,
            source: .microphone,
            sequence: 0,
            chunkID: chunkID
        )
        let bytes = cafTestBytes()
        try bytes.write(to: temporaryURL)

        let descriptor = try await committer.commitChunk(
            recordingID: recordingID,
            source: .microphone,
            sequence: 0,
            chunkID: chunkID,
            temporaryURL: temporaryURL,
            sessionStartMilliseconds: 0,
            sessionEndMilliseconds: 1_000,
            sampleRate: 48_000,
            channelCount: 1
        )

        XCTAssertEqual(descriptor.id, chunkID)
        XCTAssertEqual(descriptor.container, .caf)
        XCTAssertEqual(descriptor.codec, .linearPCM)
        XCTAssertEqual(descriptor.byteLength, Int64(bytes.count))
        XCTAssertEqual(descriptor.sha256, sha256Hex(bytes))
        XCTAssertFalse(FileManager.default.fileExists(atPath: temporaryURL.path))

        let finalURL = temporaryURL.deletingPathExtension()
        XCTAssertTrue(FileManager.default.fileExists(atPath: finalURL.path))
        let attributes = try FileManager.default.attributesOfItem(atPath: finalURL.path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)

        let maybeManifest = try await store.loadManifest(recordingID: recordingID)
        let manifest = try XCTUnwrap(maybeManifest)
        XCTAssertEqual(manifest.chunks, [descriptor])
    }

    func testInvalidCAFNeverCrossesRenameBoundary() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateChunkInvalidCAF-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)
        let committer = SuperDictateMemoryAudioChunkCommitter(store: store)
        let chunkID = UUID()
        let temporaryURL = try await committer.temporaryChunkURL(
            recordingID: recordingID,
            source: .system,
            sequence: 0,
            chunkID: chunkID
        )
        try Data("not-caf".utf8).write(to: temporaryURL)

        do {
            _ = try await committer.commitChunk(
                recordingID: recordingID,
                source: .system,
                sequence: 0,
                chunkID: chunkID,
                temporaryURL: temporaryURL,
                sessionStartMilliseconds: 0,
                sessionEndMilliseconds: 100,
                sampleRate: 48_000,
                channelCount: 2
            )
            XCTFail("invalid container should fail")
        } catch {
            XCTAssertEqual(error as? SuperDictateMemoryChunkCommitError, .invalidContainer)
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: temporaryURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: temporaryURL.deletingPathExtension().path))
    }

    func testOversizedChunkStaysPartial() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateChunkOversize-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)
        let policy = SuperDictateMemoryChunkPolicy(maximumChunkBytes: 8)
        let committer = SuperDictateMemoryAudioChunkCommitter(store: store, policy: policy)
        let chunkID = UUID()
        let temporaryURL = try await committer.temporaryChunkURL(
            recordingID: recordingID,
            source: .microphone,
            sequence: 0,
            chunkID: chunkID
        )
        let bytes = cafTestBytes("payload-too-large")
        try bytes.write(to: temporaryURL)

        do {
            _ = try await committer.commitChunk(
                recordingID: recordingID,
                source: .microphone,
                sequence: 0,
                chunkID: chunkID,
                temporaryURL: temporaryURL,
                sessionStartMilliseconds: 0,
                sessionEndMilliseconds: 100,
                sampleRate: 48_000,
                channelCount: 1
            )
            XCTFail("oversized chunk should fail before rename")
        } catch {
            XCTAssertEqual(
                error as? SuperDictateMemoryChunkCommitError,
                .fileTooLarge(Int64(bytes.count), 8)
            )
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: temporaryURL.path))
    }

    func testReadyPackageRejectsNewChunkBeforeRename() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateChunkReady-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)
        _ = try await store.beginFinalization(recordingID: recordingID)
        _ = try await store.markReady(recordingID: recordingID)

        let committer = SuperDictateMemoryAudioChunkCommitter(store: store)
        let chunkID = UUID()
        let temporaryURL = try await committer.temporaryChunkURL(
            recordingID: recordingID,
            source: .microphone,
            sequence: 0,
            chunkID: chunkID
        )
        try cafTestBytes().write(to: temporaryURL)

        do {
            _ = try await committer.commitChunk(
                recordingID: recordingID,
                source: .microphone,
                sequence: 0,
                chunkID: chunkID,
                temporaryURL: temporaryURL,
                sessionStartMilliseconds: 0,
                sessionEndMilliseconds: 100,
                sampleRate: 48_000,
                channelCount: 1
            )
            XCTFail("ready package should be terminal")
        } catch {
            XCTAssertEqual(
                error as? SuperDictateMemoryManifestError,
                .chunkAppendNotAllowed(.ready)
            )
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: temporaryURL.path))
    }

    func testSymlinkPartialIsRejectedWithoutFollowingTarget() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateChunkSymlink-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)
        let committer = SuperDictateMemoryAudioChunkCommitter(store: store)
        let chunkID = UUID()
        let temporaryURL = try await committer.temporaryChunkURL(
            recordingID: recordingID,
            source: .system,
            sequence: 0,
            chunkID: chunkID
        )
        let outside = root.appendingPathComponent("outside.caf")
        try cafTestBytes().write(to: outside)
        try FileManager.default.createSymbolicLink(at: temporaryURL, withDestinationURL: outside)

        do {
            _ = try await committer.commitChunk(
                recordingID: recordingID,
                source: .system,
                sequence: 0,
                chunkID: chunkID,
                temporaryURL: temporaryURL,
                sessionStartMilliseconds: 0,
                sessionEndMilliseconds: 100,
                sampleRate: 48_000,
                channelCount: 2
            )
            XCTFail("symlink partial should be rejected")
        } catch {
            XCTAssertEqual(error as? SuperDictateMemoryChunkCommitError, .unsafeFileType)
        }
    }

    func testPostRenameManifestFailurePreservesOrphanForRecovery() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateChunkRecovery-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)
        let committer = SuperDictateMemoryAudioChunkCommitter(store: store)

        let firstID = UUID()
        let firstTemporaryURL = try await committer.temporaryChunkURL(
            recordingID: recordingID,
            source: .microphone,
            sequence: 0,
            chunkID: firstID
        )
        try cafTestBytes("first").write(to: firstTemporaryURL)
        let first = try await committer.commitChunk(
            recordingID: recordingID,
            source: .microphone,
            sequence: 0,
            chunkID: firstID,
            temporaryURL: firstTemporaryURL,
            sessionStartMilliseconds: 0,
            sessionEndMilliseconds: 100,
            sampleRate: 48_000,
            channelCount: 1
        )

        let secondID = UUID()
        let secondTemporaryURL = try await committer.temporaryChunkURL(
            recordingID: recordingID,
            source: .microphone,
            sequence: 0,
            chunkID: secondID
        )
        try cafTestBytes("orphan").write(to: secondTemporaryURL)

        do {
            _ = try await committer.commitChunk(
                recordingID: recordingID,
                source: .microphone,
                sequence: 0,
                chunkID: secondID,
                temporaryURL: secondTemporaryURL,
                sessionStartMilliseconds: 100,
                sessionEndMilliseconds: 200,
                sampleRate: 48_000,
                channelCount: 1
            )
            XCTFail("duplicate manifest sequence should require recovery after rename")
        } catch {
            XCTAssertEqual(
                error as? SuperDictateMemoryChunkCommitError,
                .recoveryRequired(recordingID: recordingID, chunkID: secondID)
            )
        }

        let orphanURL = secondTemporaryURL.deletingPathExtension()
        XCTAssertTrue(FileManager.default.fileExists(atPath: orphanURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: secondTemporaryURL.path))

        let maybeManifest = try await store.loadManifest(recordingID: recordingID)
        let manifest = try XCTUnwrap(maybeManifest)
        XCTAssertEqual(manifest.chunks, [first])
    }
}
