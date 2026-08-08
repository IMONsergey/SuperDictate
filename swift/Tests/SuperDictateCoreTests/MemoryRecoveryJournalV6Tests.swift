import CryptoKit
import Foundation
import XCTest
@testable import SuperDictateCore

extension ProductStateTests {
    private func journalV6SHA(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func journalV6Event(
        kind: SuperDictateMemoryRecoveryEventKind,
        recordingID: UUID,
        chunkID: UUID,
        sequence: Int = 0,
        sha256: String? = nil
    ) throws -> SuperDictateMemoryRecoveryEvent {
        try SuperDictateMemoryRecoveryEvent(
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
            sessionStartMilliseconds: Int64(sequence) * 1_000,
            sessionEndMilliseconds: Int64(sequence + 1) * 1_000,
            sampleRate: 48_000,
            channelCount: 1,
            byteLength: 4_096,
            sha256: sha256
        )
    }

    func testMemoryRecoveryJournalV6TruncatesTornTailBeforeNextAppend() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateJournalV6Torn-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        let firstID = UUID()
        let secondID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)

        let first = try journalV6Event(
            kind: .chunkPrepared,
            recordingID: recordingID,
            chunkID: firstID
        )
        try await store.appendRecoveryEvent(first)

        let url = await store.recoveryJournalURL(recordingID: recordingID)
        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("{\"broken\":".utf8))
        try handle.close()

        let before = try await store.recoveryJournalSnapshot(recordingID: recordingID)
        XCTAssertEqual(before.events, [first])
        XCTAssertTrue(before.ignoredPartialTailLine)

        let second = try journalV6Event(
            kind: .chunkPrepared,
            recordingID: recordingID,
            chunkID: secondID,
            sequence: 1
        )
        try await store.appendRecoveryEvent(second)

        let after = try await store.recoveryJournalSnapshot(recordingID: recordingID)
        XCTAssertEqual(after.events, [first, second])
        XCTAssertFalse(after.ignoredPartialTailLine)
        let data = try Data(contentsOf: url)
        XCTAssertEqual(data.last, UInt8(ascii: "\n"))
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("broken"))
    }

    func testMemoryRecoveryJournalV6PreservesValidUnterminatedJSONBeforeNextAppend() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateJournalV6Separator-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        let firstID = UUID()
        let secondID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)

        let first = try journalV6Event(
            kind: .chunkPrepared,
            recordingID: recordingID,
            chunkID: firstID
        )
        try await store.appendRecoveryEvent(first)
        let url = await store.recoveryJournalURL(recordingID: recordingID)

        var data = try Data(contentsOf: url)
        XCTAssertEqual(data.last, UInt8(ascii: "\n"))
        data.removeLast()
        try data.write(to: url)

        let unterminated = try await store.recoveryJournalSnapshot(recordingID: recordingID)
        XCTAssertEqual(unterminated.events, [first])
        XCTAssertFalse(unterminated.ignoredPartialTailLine)

        let second = try journalV6Event(
            kind: .chunkPrepared,
            recordingID: recordingID,
            chunkID: secondID,
            sequence: 1
        )
        try await store.appendRecoveryEvent(second)

        let final = try await store.recoveryJournalSnapshot(recordingID: recordingID)
        XCTAssertEqual(final.events, [first, second])
        XCTAssertFalse(final.ignoredPartialTailLine)
        XCTAssertEqual(try Data(contentsOf: url).last, UInt8(ascii: "\n"))
    }

    func testMemoryRecoveryJournalV6EnforcesPreparedThenCommittedStateMachine() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateJournalV6State-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        let chunkID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)

        let checksum = journalV6SHA("source")
        let committedFirst = try journalV6Event(
            kind: .chunkCommitted,
            recordingID: recordingID,
            chunkID: chunkID,
            sha256: checksum
        )
        do {
            try await store.appendRecoveryEvent(committedFirst)
            XCTFail("committed-first journal event must be rejected")
        } catch let error as SuperDictateMemoryRecoveryJournalError {
            XCTAssertEqual(
                error,
                .invalidTransition(
                    chunkID: chunkID,
                    previous: nil,
                    next: .chunkCommitted
                )
            )
        }

        let prepared = try journalV6Event(
            kind: .chunkPrepared,
            recordingID: recordingID,
            chunkID: chunkID
        )
        try await store.appendRecoveryEvent(prepared)

        do {
            try await store.appendRecoveryEvent(prepared)
            XCTFail("duplicate prepared event must be rejected")
        } catch let error as SuperDictateMemoryRecoveryJournalError {
            XCTAssertEqual(
                error,
                .invalidTransition(
                    chunkID: chunkID,
                    previous: .chunkPrepared,
                    next: .chunkPrepared
                )
            )
        }

        let committed = try journalV6Event(
            kind: .chunkCommitted,
            recordingID: recordingID,
            chunkID: chunkID,
            sha256: checksum
        )
        try await store.appendRecoveryEvent(committed)

        do {
            try await store.appendRecoveryEvent(committed)
            XCTFail("event after committed must be rejected")
        } catch let error as SuperDictateMemoryRecoveryJournalError {
            XCTAssertEqual(
                error,
                .invalidTransition(
                    chunkID: chunkID,
                    previous: .chunkCommitted,
                    next: .chunkCommitted
                )
            )
        }
    }

    func testMemoryRecoveryJournalV6RequiresChecksumOnlyForCommittedEvents() throws {
        let recordingID = UUID()
        let chunkID = UUID()
        XCTAssertNoThrow(
            try journalV6Event(
                kind: .chunkPrepared,
                recordingID: recordingID,
                chunkID: chunkID
            )
        )
        XCTAssertThrowsError(
            try journalV6Event(
                kind: .chunkPrepared,
                recordingID: recordingID,
                chunkID: chunkID,
                sha256: journalV6SHA("not allowed")
            )
        )
        XCTAssertThrowsError(
            try journalV6Event(
                kind: .chunkCommitted,
                recordingID: recordingID,
                chunkID: chunkID,
                sha256: nil
            )
        )
        XCTAssertNoThrow(
            try journalV6Event(
                kind: .chunkCommitted,
                recordingID: recordingID,
                chunkID: chunkID,
                sha256: journalV6SHA("required")
            )
        )
    }
}
