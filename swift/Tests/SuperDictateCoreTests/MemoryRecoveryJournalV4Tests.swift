import Foundation
import XCTest
@testable import SuperDictateCore

extension ProductStateTests {
    private func v4JournalEvent(
        kind: SuperDictateMemoryRecoveryEventKind,
        recordingID: UUID,
        chunkID: UUID,
        sequence: Int = 0,
        source: SuperDictateMemoryAudioSource = .microphone,
        byteLength: Int64 = 4_096,
        sha256: String? = nil
    ) throws -> SuperDictateMemoryRecoveryEvent {
        try SuperDictateMemoryRecoveryEvent(
            kind: kind,
            recordingID: recordingID,
            chunkID: chunkID,
            source: source,
            sequence: sequence,
            relativePath: SuperDictateMemoryAudioChunk.canonicalRelativePath(
                source: source,
                sequence: sequence,
                chunkID: chunkID
            ),
            sessionStartMilliseconds: 0,
            sessionEndMilliseconds: 1_000,
            sampleRate: 48_000,
            channelCount: source == .system ? 2 : 1,
            byteLength: byteLength,
            sha256: sha256
        )
    }

    func testJournalAcceptsOnlyPreparedThenCommitted() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateJournalV4-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        let chunkID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)

        let prepared = try v4JournalEvent(
            kind: .chunkPrepared,
            recordingID: recordingID,
            chunkID: chunkID
        )
        let committed = try v4JournalEvent(
            kind: .chunkCommitted,
            recordingID: recordingID,
            chunkID: chunkID,
            sha256: String(repeating: "a", count: 64)
        )
        try await store.appendRecoveryEvent(prepared)
        try await store.appendRecoveryEvent(committed)

        let snapshot = try await store.recoveryJournalSnapshot(recordingID: recordingID)
        XCTAssertEqual(snapshot.events.map(\.kind), [.chunkPrepared, .chunkCommitted])
        XCTAssertNil(snapshot.events[0].sha256)
        XCTAssertEqual(snapshot.events[1].sha256, String(repeating: "a", count: 64))

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

    func testCommittedFirstAndMetadataMutationAreRejected() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateJournalV4Transitions-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        let firstChunk = UUID()
        _ = try await store.createPackage(recordingID: recordingID)

        do {
            try await store.appendRecoveryEvent(
                v4JournalEvent(
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
            v4JournalEvent(
                kind: .chunkPrepared,
                recordingID: recordingID,
                chunkID: secondChunk,
                byteLength: 100
            )
        )
        do {
            try await store.appendRecoveryEvent(
                v4JournalEvent(
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

    func testJournalRejectsSymlinkAndToleratesOnlyIncompleteTail() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateJournalV4Safety-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)

        let tailID = UUID()
        _ = try await store.createPackage(recordingID: tailID)
        let prepared = try v4JournalEvent(
            kind: .chunkPrepared,
            recordingID: tailID,
            chunkID: UUID()
        )
        try await store.appendRecoveryEvent(prepared)
        let tailURL = await store.recoveryJournalURL(recordingID: tailID)
        let handle = try FileHandle(forWritingTo: tailURL)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("{\"schemaVersion\":".utf8))
        try handle.close()
        let tailSnapshot = try await store.recoveryJournalSnapshot(recordingID: tailID)
        XCTAssertTrue(tailSnapshot.ignoredPartialTailLine)
        XCTAssertEqual(tailSnapshot.events, [prepared])

        let symlinkID = UUID()
        _ = try await store.createPackage(recordingID: symlinkID)
        let journalURL = await store.recoveryJournalURL(recordingID: symlinkID)
        let outside = root.appendingPathComponent("outside.jsonl")
        try Data().write(to: outside)
        try FileManager.default.createSymbolicLink(at: journalURL, withDestinationURL: outside)
        do {
            _ = try await store.recoveryJournalSnapshot(recordingID: symlinkID)
            XCTFail("journal symlink must be unsafe")
        } catch {
            XCTAssertEqual(error as? SuperDictateMemoryRecoveryJournalError, .unsafeFileType)
        }
    }
}
