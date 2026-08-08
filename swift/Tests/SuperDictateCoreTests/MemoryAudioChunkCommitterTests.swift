import CryptoKit
import Foundation
import XCTest
@testable import SuperDictateCore

extension ProductStateTests {
    private func recoveryV2CAF(_ payload: String) -> Data {
        var data = Data("caff".utf8)
        data.append(Data(payload.utf8))
        return data
    }

    private func recoveryV2SHA(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    func testMemoryChunkCommitPersistsChecksumBoundCommittedMarker() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateCommitV2-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        let chunkID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)
        let committer = SuperDictateMemoryAudioChunkCommitter(store: store)
        let temp = try await committer.temporaryChunkURL(
            recordingID: recordingID,
            source: .system,
            sequence: 0,
            chunkID: chunkID
        )
        let bytes = recoveryV2CAF("source")
        try bytes.write(to: temp)

        let descriptor = try await committer.commitChunk(
            recordingID: recordingID,
            source: .system,
            sequence: 0,
            chunkID: chunkID,
            temporaryURL: temp,
            sessionStartMilliseconds: 100,
            sessionEndMilliseconds: 1_100,
            sampleRate: 48_000,
            channelCount: 2
        )
        XCTAssertEqual(descriptor.sha256, recoveryV2SHA(bytes))

        let journal = try await store.recoveryJournalSnapshot(recordingID: recordingID)
        XCTAssertEqual(journal.events.map(\.kind), [.chunkPrepared, .chunkCommitted])
        XCTAssertNil(journal.events.first?.sha256)
        XCTAssertEqual(journal.events.last?.sha256, descriptor.sha256)
    }

    func testInvalidCAFStaysPartialBeforeDurabilityBoundary() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateInvalidV2-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)
        let committer = SuperDictateMemoryAudioChunkCommitter(store: store)
        let temp = try await committer.temporaryChunkURL(
            recordingID: recordingID,
            source: .microphone,
            sequence: 0,
            chunkID: UUID()
        )
        try Data("not-caf".utf8).write(to: temp)

        do {
            _ = try await committer.commitChunk(
                recordingID: recordingID,
                source: .microphone,
                sequence: 0,
                chunkID: UUID(),
                temporaryURL: temp,
                sessionStartMilliseconds: 0,
                sessionEndMilliseconds: 1,
                sampleRate: 48_000,
                channelCount: 1
            )
            XCTFail("invalid CAF must fail")
        } catch {
            XCTAssertTrue(FileManager.default.fileExists(atPath: temp.path))
        }
    }

    func testPostRenameManifestFailureLeavesPreparedOrphan() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateOrphanV2-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)
        let committer = SuperDictateMemoryAudioChunkCommitter(store: store)

        let firstID = UUID()
        let firstTemp = try await committer.temporaryChunkURL(
            recordingID: recordingID, source: .microphone, sequence: 0, chunkID: firstID
        )
        try recoveryV2CAF("first").write(to: firstTemp)
        _ = try await committer.commitChunk(
            recordingID: recordingID, source: .microphone, sequence: 0, chunkID: firstID,
            temporaryURL: firstTemp, sessionStartMilliseconds: 0, sessionEndMilliseconds: 100,
            sampleRate: 48_000, channelCount: 1
        )

        let orphanID = UUID()
        let orphanTemp = try await committer.temporaryChunkURL(
            recordingID: recordingID, source: .microphone, sequence: 0, chunkID: orphanID
        )
        try recoveryV2CAF("orphan").write(to: orphanTemp)
        do {
            _ = try await committer.commitChunk(
                recordingID: recordingID, source: .microphone, sequence: 0, chunkID: orphanID,
                temporaryURL: orphanTemp, sessionStartMilliseconds: 100, sessionEndMilliseconds: 200,
                sampleRate: 48_000, channelCount: 1
            )
            XCTFail("duplicate sequence should require recovery")
        } catch {
            XCTAssertEqual(
                error as? SuperDictateMemoryChunkCommitError,
                .recoveryRequired(recordingID: recordingID, chunkID: orphanID)
            )
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: orphanTemp.deletingPathExtension().path))
        let journal = try await store.recoveryJournalSnapshot(recordingID: recordingID)
        XCTAssertEqual(journal.latestEventByChunkID[orphanID]?.kind, .chunkPrepared)
        XCTAssertNil(journal.latestEventByChunkID[orphanID]?.sha256)
    }
}
