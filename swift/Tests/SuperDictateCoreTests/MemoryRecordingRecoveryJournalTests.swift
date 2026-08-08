import Foundation
import XCTest
@testable import SuperDictateCore

extension ProductStateTests {
    private func recoveryEvent(
        kind: SuperDictateMemoryRecoveryEventKind,
        recordingID: UUID,
        chunkID: UUID,
        sequence: Int = 0
    ) throws -> SuperDictateMemoryRecoveryEvent {
        try SuperDictateMemoryRecoveryEvent(
            kind: kind,
            recordingID: recordingID,
            chunkID: chunkID,
            source: .microphone,
            sequence: sequence,
            relativePath: "audio/microphone/000000__\(chunkID.uuidString.lowercased()).caf",
            sessionStartMilliseconds: 0,
            sessionEndMilliseconds: 1_000,
            sampleRate: 48_000,
            channelCount: 1,
            byteLength: 4_096
        )
    }

    func testMemoryRecoveryJournalRoundTripsPreparedAndCommittedEvents() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateRecoveryJournal-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        let chunkID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)

        let prepared = try recoveryEvent(
            kind: .chunkPrepared,
            recordingID: recordingID,
            chunkID: chunkID
        )
        let committed = try recoveryEvent(
            kind: .chunkCommitted,
            recordingID: recordingID,
            chunkID: chunkID
        )
        try await store.appendRecoveryEvent(prepared)
        try await store.appendRecoveryEvent(committed)

        let snapshot = try await store.recoveryJournalSnapshot(recordingID: recordingID)
        XCTAssertEqual(snapshot.events, [prepared, committed])
        XCTAssertFalse(snapshot.ignoredPartialTailLine)
        XCTAssertEqual(snapshot.latestEventByChunkID[chunkID]?.kind, .chunkCommitted)

        let journalURL = await store.recoveryJournalURL(recordingID: recordingID)
        let attributes = try FileManager.default.attributesOfItem(atPath: journalURL.path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
    }

    func testMemoryRecoveryJournalIgnoresOnlyIncompleteTailLine() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateRecoveryTail-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        let chunkID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)
        let prepared = try recoveryEvent(
            kind: .chunkPrepared,
            recordingID: recordingID,
            chunkID: chunkID
        )
        try await store.appendRecoveryEvent(prepared)

        let journalURL = await store.recoveryJournalURL(recordingID: recordingID)
        let handle = try FileHandle(forWritingTo: journalURL)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("{\"schemaVersion\":".utf8))
        try handle.close()

        let snapshot = try await store.recoveryJournalSnapshot(recordingID: recordingID)
        XCTAssertEqual(snapshot.events, [prepared])
        XCTAssertTrue(snapshot.ignoredPartialTailLine)
    }

    func testMemoryRecoveryJournalRejectsCorruptionBeforeTail() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateRecoveryCorrupt-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        let firstChunk = UUID()
        let secondChunk = UUID()
        _ = try await store.createPackage(recordingID: recordingID)
        try await store.appendRecoveryEvent(
            recoveryEvent(kind: .chunkPrepared, recordingID: recordingID, chunkID: firstChunk)
        )

        let journalURL = await store.recoveryJournalURL(recordingID: recordingID)
        let handle = try FileHandle(forWritingTo: journalURL)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("not-json\n".utf8))
        try handle.close()

        try await store.appendRecoveryEvent(
            recoveryEvent(kind: .chunkPrepared, recordingID: recordingID, chunkID: secondChunk, sequence: 1)
        )

        do {
            _ = try await store.recoveryJournalSnapshot(recordingID: recordingID)
            XCTFail("middle journal corruption must be fatal")
        } catch {
            XCTAssertEqual(
                error as? SuperDictateMemoryRecoveryJournalError,
                .corruptLine(2)
            )
        }
    }

    func testMemoryRecoveryJournalRejectsSymlinkFile() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateRecoverySymlink-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        let chunkID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)

        let journalURL = await store.recoveryJournalURL(recordingID: recordingID)
        let outside = root.appendingPathComponent("outside.jsonl")
        try Data().write(to: outside)
        try FileManager.default.createSymbolicLink(at: journalURL, withDestinationURL: outside)

        do {
            try await store.appendRecoveryEvent(
                recoveryEvent(kind: .chunkPrepared, recordingID: recordingID, chunkID: chunkID)
            )
            XCTFail("symlink recovery journal must not be followed")
        } catch {
            XCTAssertEqual(
                error as? SuperDictateMemoryRecoveryJournalError,
                .unsafeFileType
            )
        }
    }

    func testMemoryRecoveryEventRejectsCrossSourceRelativePath() {
        XCTAssertThrowsError(
            try SuperDictateMemoryRecoveryEvent(
                kind: .chunkPrepared,
                recordingID: UUID(),
                chunkID: UUID(),
                source: .system,
                sequence: 0,
                relativePath: "audio/microphone/wrong.caf",
                sessionStartMilliseconds: 0,
                sessionEndMilliseconds: 1,
                sampleRate: 48_000,
                channelCount: 2,
                byteLength: 100
            )
        ) { error in
            XCTAssertEqual(
                error as? SuperDictateMemoryRecoveryJournalError,
                .invalidRelativePath("audio/microphone/wrong.caf")
            )
        }
    }
}
