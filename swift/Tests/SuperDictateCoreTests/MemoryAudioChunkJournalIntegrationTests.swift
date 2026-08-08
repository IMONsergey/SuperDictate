import Foundation
import XCTest
@testable import SuperDictateCore

extension ProductStateTests {
    private func journalCAFBytes(_ payload: String) -> Data {
        var data = Data("caff".utf8)
        data.append(Data(payload.utf8))
        return data
    }

    func testSuccessfulMemoryChunkWritesPreparedThenCommittedRecoveryMarkers() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateJournalCommit-\(UUID().uuidString)", isDirectory: true)
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
        try journalCAFBytes("committed").write(to: temp)

        _ = try await committer.commitChunk(
            recordingID: recordingID,
            source: .system,
            sequence: 0,
            chunkID: chunkID,
            temporaryURL: temp,
            sessionStartMilliseconds: 250,
            sessionEndMilliseconds: 1_250,
            sampleRate: 48_000,
            channelCount: 2
        )

        let snapshot = try await store.recoveryJournalSnapshot(recordingID: recordingID)
        XCTAssertEqual(snapshot.events.map(\.kind), [.chunkPrepared, .chunkCommitted])
        XCTAssertEqual(snapshot.events.map(\.chunkID), [chunkID, chunkID])
        XCTAssertEqual(snapshot.latestEventByChunkID[chunkID]?.kind, .chunkCommitted)
    }

    func testPostRenameManifestFailureLeavesPreparedMarkerForRecovery() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateJournalOrphan-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)
        let committer = SuperDictateMemoryAudioChunkCommitter(store: store)

        let firstID = UUID()
        let firstTemp = try await committer.temporaryChunkURL(
            recordingID: recordingID,
            source: .microphone,
            sequence: 0,
            chunkID: firstID
        )
        try journalCAFBytes("first").write(to: firstTemp)
        _ = try await committer.commitChunk(
            recordingID: recordingID,
            source: .microphone,
            sequence: 0,
            chunkID: firstID,
            temporaryURL: firstTemp,
            sessionStartMilliseconds: 0,
            sessionEndMilliseconds: 100,
            sampleRate: 48_000,
            channelCount: 1
        )

        let orphanID = UUID()
        let orphanTemp = try await committer.temporaryChunkURL(
            recordingID: recordingID,
            source: .microphone,
            sequence: 0,
            chunkID: orphanID
        )
        try journalCAFBytes("orphan").write(to: orphanTemp)

        do {
            _ = try await committer.commitChunk(
                recordingID: recordingID,
                source: .microphone,
                sequence: 0,
                chunkID: orphanID,
                temporaryURL: orphanTemp,
                sessionStartMilliseconds: 100,
                sessionEndMilliseconds: 200,
                sampleRate: 48_000,
                channelCount: 1
            )
            XCTFail("duplicate sequence should fail after rename")
        } catch {
            XCTAssertEqual(
                error as? SuperDictateMemoryChunkCommitError,
                .recoveryRequired(recordingID: recordingID, chunkID: orphanID)
            )
        }

        let snapshot = try await store.recoveryJournalSnapshot(recordingID: recordingID)
        XCTAssertEqual(snapshot.latestEventByChunkID[firstID]?.kind, .chunkCommitted)
        XCTAssertEqual(snapshot.latestEventByChunkID[orphanID]?.kind, .chunkPrepared)
    }
}
