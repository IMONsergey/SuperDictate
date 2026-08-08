import Foundation
import XCTest
@testable import SuperDictateCore

extension ProductStateTests {
    private func v3JournalEvent(
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

    func testJournalAcceptsOnlyPreparedThenCommittedForOneChunk() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateJournalStateV3-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        let chunkID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)

        let prepared = try v3JournalEvent(
            kind: .chunkPrepared,
            recordingID: recordingID,
            chunkID: chunkID
        )
        let committed = try v3JournalEvent(
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
            try await store.appendRecoveryEvent(
                v3JournalEvent(
                    kind: .chunkPrepared,
                    recordingID: recordingID,
                    chunkID: chunkID
                )
            )
            XCTFail("events after committed must be rejected")
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

    func testJournalRejectsCommittedWithoutPrepared() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateJournalCommittedFirstV3-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        let chunkID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)

        do {
            try await store.appendRecoveryEvent(
                v3JournalEvent(
                    kind: .chunkCommitted,
                    recordingID: recordingID,
                    chunkID: chunkID,
                    sha256: String(repeating: "b", count: 64)
                )
            )
            XCTFail("committed-first is not a valid transaction")
        } catch {
            XCTAssertEqual(
                error as? SuperDictateMemoryRecoveryJournalError,
                .invalidTransition(
                    chunkID: chunkID,
                    previous: nil,
                    next: .chunkCommitted
                )
            )
        }
    }

    func testJournalRejectsMetadataChangeBetweenPreparedAndCommitted() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateJournalConflictV3-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        let chunkID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)
        try await store.appendRecoveryEvent(
            v3JournalEvent(
                kind: .chunkPrepared,
                recordingID: recordingID,
                chunkID: chunkID,
                byteLength: 100
            )
        )

        do {
            try await store.appendRecoveryEvent(
                v3JournalEvent(
                    kind: .chunkCommitted,
                    recordingID: recordingID,
                    chunkID: chunkID,
                    byteLength: 101,
                    sha256: String(repeating: "c", count: 64)
                )
            )
            XCTFail("transaction metadata cannot change after prepare")
        } catch {
            XCTAssertEqual(
                error as? SuperDictateMemoryRecoveryJournalError,
                .conflictingChunkMetadata(chunkID)
            )
        }
    }

    func testJournalToleratesOnlyOneIncompletePhysicalTail() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateJournalTailV3-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        let chunkID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)
        let prepared = try v3JournalEvent(
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

        let snapshot = try await store.recoveryJournalSnapshot(recordingID: recordingID)
        XCTAssertEqual(snapshot.events, [prepared])
        XCTAssertTrue(snapshot.ignoredPartialTailLine)
    }
}
