import Foundation
import XCTest
@testable import SuperDictateCore

extension ProductStateTests {
    private func journalV2Event(
        kind: SuperDictateMemoryRecoveryEventKind,
        recordingID: UUID,
        chunkID: UUID,
        sequence: Int = 0
    ) throws -> SuperDictateMemoryRecoveryEvent {
        let sha = kind == .chunkCommitted ? String(repeating: "a", count: 64) : nil
        return try SuperDictateMemoryRecoveryEvent(
            kind: kind,
            recordingID: recordingID,
            chunkID: chunkID,
            source: .microphone,
            sequence: sequence,
            relativePath: SuperDictateMemoryAudioChunk.canonicalRelativePath(
                source: .microphone,
                sequence: sequence,
                chunkID: chunkID
            ),
            sessionStartMilliseconds: 0,
            sessionEndMilliseconds: 1_000,
            sampleRate: 48_000,
            channelCount: 1,
            byteLength: 4_096,
            sha256: sha
        )
    }

    func testChecksumAwareJournalRoundTripAndPermissions() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateJournalV2-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        let chunkID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)
        let prepared = try journalV2Event(kind: .chunkPrepared, recordingID: recordingID, chunkID: chunkID)
        let committed = try journalV2Event(kind: .chunkCommitted, recordingID: recordingID, chunkID: chunkID)
        try await store.appendRecoveryEvent(prepared)
        try await store.appendRecoveryEvent(committed)

        let snapshot = try await store.recoveryJournalSnapshot(recordingID: recordingID)
        XCTAssertEqual(snapshot.events, [prepared, committed])
        XCTAssertNil(snapshot.events[0].sha256)
        XCTAssertEqual(snapshot.events[1].sha256, String(repeating: "a", count: 64))
        let url = await store.recoveryJournalURL(recordingID: recordingID)
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        XCTAssertEqual((attrs[.posixPermissions] as? NSNumber)?.intValue, 0o600)
    }

    func testJournalIgnoresOnlyIncompletePhysicalTail() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateJournalTailV2-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)
        let prepared = try journalV2Event(kind: .chunkPrepared, recordingID: recordingID, chunkID: UUID())
        try await store.appendRecoveryEvent(prepared)
        let url = await store.recoveryJournalURL(recordingID: recordingID)
        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("{\"schemaVersion\":".utf8))
        try handle.close()

        let snapshot = try await store.recoveryJournalSnapshot(recordingID: recordingID)
        XCTAssertEqual(snapshot.events, [prepared])
        XCTAssertTrue(snapshot.ignoredPartialTailLine)
    }

    func testJournalRejectsMiddleCorruption() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateJournalCorruptV2-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)
        try await store.appendRecoveryEvent(
            journalV2Event(kind: .chunkPrepared, recordingID: recordingID, chunkID: UUID())
        )
        let url = await store.recoveryJournalURL(recordingID: recordingID)
        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("bad-json\n".utf8))
        try handle.close()
        try await store.appendRecoveryEvent(
            journalV2Event(kind: .chunkPrepared, recordingID: recordingID, chunkID: UUID(), sequence: 1)
        )
        do {
            _ = try await store.recoveryJournalSnapshot(recordingID: recordingID)
            XCTFail("middle corruption must be fatal")
        } catch {
            XCTAssertEqual(error as? SuperDictateMemoryRecoveryJournalError, .corruptLine(2))
        }
    }

    func testJournalSymlinkIsRejected() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateJournalSymlinkV2-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)
        let url = await store.recoveryJournalURL(recordingID: recordingID)
        let outside = root.appendingPathComponent("outside.jsonl")
        try Data().write(to: outside)
        try FileManager.default.createSymbolicLink(at: url, withDestinationURL: outside)
        do {
            try await store.appendRecoveryEvent(
                journalV2Event(kind: .chunkPrepared, recordingID: recordingID, chunkID: UUID())
            )
            XCTFail("symlink must be rejected")
        } catch {
            XCTAssertEqual(error as? SuperDictateMemoryRecoveryJournalError, .unsafeFileType)
        }
    }
}
