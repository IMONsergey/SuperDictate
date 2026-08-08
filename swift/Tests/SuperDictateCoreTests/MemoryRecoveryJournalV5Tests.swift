import Foundation
import XCTest
@testable import SuperDictateCore

extension ProductStateTests {
    private func v5JournalEvent(
        kind: SuperDictateMemoryRecoveryEventKind,
        recordingID: UUID,
        chunkID: UUID,
        sequence: Int = 0,
        byteLength: Int64 = 4_096,
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
            byteLength: byteLength,
            sha256: sha256
        )
    }

    func testV5JournalAcceptsOnlyPreparedThenCommitted() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateJournalV5-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        let chunkID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)

        let prepared = try v5JournalEvent(
            kind: .chunkPrepared,
            recordingID: recordingID,
            chunkID: chunkID
        )
        let committed = try v5JournalEvent(
            kind: .chunkCommitted,
            recordingID: recordingID,
            chunkID: chunkID,
            sha256: String(repeating: "a", count: 64)
        )
        try await store.appendRecoveryEvent(prepared)
        try await store.appendRecoveryEvent(committed)

        let snapshot = try await store.recoveryJournalSnapshot(recordingID: recordingID)
        XCTAssertEqual(snapshot.events, [prepared, committed])
        XCTAssertNil(snapshot.events.first?.sha256)
        XCTAssertEqual(snapshot.events.last?.sha256, String(repeating: "a", count: 64))

        do {
            try await store.appendRecoveryEvent(prepared)
            XCTFail("event after committed must fail")
        } catch {
            XCTAssertEqual(
                error as? SuperDictateMemoryRecoveryJournalError,
                .invalidTransition(
                    chunkID: chunkID,
                    previous: .chunkCommitted,
                    next: .chunkPrepared
                )
            )
        }
    }

    func testV5JournalRejectsCommittedFirstAndMetadataMutation() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateJournalV5Transitions-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)

        let firstChunk = UUID()
        do {
            try await store.appendRecoveryEvent(
                v5JournalEvent(
                    kind: .chunkCommitted,
                    recordingID: recordingID,
                    chunkID: firstChunk,
                    sha256: String(repeating: "b", count: 64)
                )
            )
            XCTFail("committed-first must fail")
        } catch {
            XCTAssertEqual(
                error as? SuperDictateMemoryRecoveryJournalError,
                .invalidTransition(
                    chunkID: firstChunk,
                    previous: nil,
                    next: .chunkCommitted
                )
            )
        }

        let secondChunk = UUID()
        try await store.appendRecoveryEvent(
            v5JournalEvent(
                kind: .chunkPrepared,
                recordingID: recordingID,
                chunkID: secondChunk,
                byteLength: 100
            )
        )
        do {
            try await store.appendRecoveryEvent(
                v5JournalEvent(
                    kind: .chunkCommitted,
                    recordingID: recordingID,
                    chunkID: secondChunk,
                    byteLength: 101,
                    sha256: String(repeating: "c", count: 64)
                )
            )
            XCTFail("prepared metadata must be immutable")
        } catch {
            XCTAssertEqual(
                error as? SuperDictateMemoryRecoveryJournalError,
                .conflictingChunkMetadata(secondChunk)
            )
        }
    }

    func testV5AppendTruncatesInvalidTornTailBeforeNextEvent() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateJournalV5Torn-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        let chunkID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)

        let prepared = try v5JournalEvent(
            kind: .chunkPrepared,
            recordingID: recordingID,
            chunkID: chunkID
        )
        try await store.appendRecoveryEvent(prepared)
        let url = await store.recoveryJournalURL(recordingID: recordingID)
        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("{\"schemaVersion\":".utf8))
        try handle.close()

        let before = try await store.recoveryJournalSnapshot(recordingID: recordingID)
        XCTAssertTrue(before.ignoredPartialTailLine)
        XCTAssertEqual(before.events, [prepared])

        let committed = try v5JournalEvent(
            kind: .chunkCommitted,
            recordingID: recordingID,
            chunkID: chunkID,
            sha256: String(repeating: "d", count: 64)
        )
        try await store.appendRecoveryEvent(committed)

        let after = try await store.recoveryJournalSnapshot(recordingID: recordingID)
        XCTAssertFalse(after.ignoredPartialTailLine)
        XCTAssertEqual(after.events, [prepared, committed])
        let bytes = try Data(contentsOf: url)
        XCTAssertEqual(bytes.last, UInt8(ascii: "\n"))
    }

    func testV5AppendAddsSeparatorAfterValidJSONWithoutNewline() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateJournalV5Separator-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        let chunkID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)

        let prepared = try v5JournalEvent(
            kind: .chunkPrepared,
            recordingID: recordingID,
            chunkID: chunkID
        )
        try await store.appendRecoveryEvent(prepared)
        let url = await store.recoveryJournalURL(recordingID: recordingID)
        var bytes = try Data(contentsOf: url)
        XCTAssertEqual(bytes.last, UInt8(ascii: "\n"))
        bytes.removeLast()
        try bytes.write(to: url)

        let validUnterminated = try await store.recoveryJournalSnapshot(recordingID: recordingID)
        XCTAssertFalse(validUnterminated.ignoredPartialTailLine)
        XCTAssertEqual(validUnterminated.events, [prepared])

        let committed = try v5JournalEvent(
            kind: .chunkCommitted,
            recordingID: recordingID,
            chunkID: chunkID,
            sha256: String(repeating: "e", count: 64)
        )
        try await store.appendRecoveryEvent(committed)

        let snapshot = try await store.recoveryJournalSnapshot(recordingID: recordingID)
        XCTAssertEqual(snapshot.events, [prepared, committed])
        XCTAssertFalse(snapshot.ignoredPartialTailLine)
    }

    func testV5JournalSymlinkIsRejected() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateJournalV5Symlink-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)
        let url = await store.recoveryJournalURL(recordingID: recordingID)
        let outside = root.appendingPathComponent("outside.jsonl")
        try Data().write(to: outside)
        try FileManager.default.createSymbolicLink(at: url, withDestinationURL: outside)

        do {
            _ = try await store.recoveryJournalSnapshot(recordingID: recordingID)
            XCTFail("recovery journal symlink must be unsafe")
        } catch {
            XCTAssertEqual(error as? SuperDictateMemoryRecoveryJournalError, .unsafeFileType)
        }
    }
}
