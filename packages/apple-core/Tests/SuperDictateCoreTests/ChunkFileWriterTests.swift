import Foundation
import XCTest
@testable import SuperDictateCore

final class ChunkFileWriterTests: XCTestCase {
    func testNormalChunkClosePersistsVerifiedManifestAndJournalEvents() async throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let writer = try ChunkFileWriter(rootDirectory: root, policy: testPolicy())
        let descriptor = recordingDescriptor(id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!)
        let manifest = try await writer.createSession(
            descriptor: descriptor,
            productPolicy: RecordingMode.meeting.defaultProductPolicy,
            at: Date(timeIntervalSince1970: 100)
        )
        let assetID = UUID(uuidString: "00000000-0000-0000-0000-000000000201")!
        let chunkID = UUID(uuidString: "00000000-0000-0000-0000-000000000301")!

        try await writer.openChunk(
            recordingID: manifest.id,
            assetID: assetID,
            sequence: 0,
            chunkID: chunkID,
            at: Date(timeIntervalSince1970: 101)
        )
        try await writer.write(Data("hello ".utf8), to: manifest.id, at: Date(timeIntervalSince1970: 102))
        try await writer.write(Data("world".utf8), to: manifest.id, at: Date(timeIntervalSince1970: 103))
        let chunk = try await writer.closeChunk(
            recordingID: manifest.id,
            durationMilliseconds: 1_250,
            at: Date(timeIntervalSince1970: 104)
        )

        let store = try JSONRecordingManifestStore(rootDirectory: root)
        let loaded = try await store.load(recordingID: manifest.id)
        XCTAssertEqual(loaded?.chunks ?? [], [chunk])
        XCTAssertEqual(loaded?.chunks.first?.persistenceState, .verified)

        let chunkURL = await writer.finalizedChunkURL(
            recordingID: manifest.id,
            assetID: assetID,
            sequence: 0,
            chunkID: chunkID
        )
        XCTAssertEqual(try Data(contentsOf: chunkURL), Data("hello world".utf8))

        let journalEvents = try await writer.journalEvents(recordingID: manifest.id)
        let journalKinds = journalEvents.map(\.kind)
        XCTAssertEqual(
            journalKinds,
            [
                .sessionCreated,
                .chunkOpening,
                .chunkOpened,
                .samplesWritten,
                .samplesWritten,
                .chunkCloseRequested,
                .chunkFlushed,
                .chunkClosed,
                .checksumComputed,
                .manifestCommitStarted,
                .manifestCommitCompleted,
            ]
        )
    }

    func testStopDuringActiveChunkClosesThenFinalizesRecording() async throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let writer = try ChunkFileWriter(rootDirectory: root, policy: testPolicy())
        let manifest = try await writer.createSession(
            descriptor: recordingDescriptor(),
            productPolicy: RecordingMode.dictation.defaultProductPolicy
        )

        try await writer.openChunk(recordingID: manifest.id, assetID: UUID(), sequence: 0)
        try await writer.write(Data("audio".utf8), to: manifest.id)
        _ = try await writer.closeChunk(recordingID: manifest.id, durationMilliseconds: 900)
        let finalized = try await writer.finalizeRecording(
            recordingID: manifest.id,
            endedAt: Date(timeIntervalSince1970: 200),
            durationMilliseconds: 900
        )

        XCTAssertEqual(finalized.localState, .finalized)
        XCTAssertEqual(finalized.descriptor.endedAt, Date(timeIntervalSince1970: 200))
        XCTAssertEqual(finalized.descriptor.durationMilliseconds, 900)
        XCTAssertTrue(finalized.hasDurableLocalSource)
    }

    func testCrashAfterCloseBeforeManifestIsRecoveredIdempotently() async throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let writer = try ChunkFileWriter(
            rootDirectory: root,
            policy: testPolicy(),
            faultInjection: ChunkFileWriterFaultInjection(skipNextManifestCommit: true)
        )
        let manifest = try await writer.createSession(
            descriptor: recordingDescriptor(),
            productPolicy: RecordingMode.quickThought.defaultProductPolicy
        )
        let assetID = UUID()
        let chunkID = UUID()

        try await writer.openChunk(recordingID: manifest.id, assetID: assetID, sequence: 0, chunkID: chunkID)
        try await writer.write(Data("durable bytes".utf8), to: manifest.id)
        do {
            _ = try await writer.closeChunk(recordingID: manifest.id, durationMilliseconds: 2_000)
            XCTFail("close should simulate a crash before manifest commit")
        } catch ChunkWriterError.recoveryRequired(let recordingID) {
            XCTAssertEqual(recordingID, manifest.id)
        }

        let recoveredWriter = try ChunkFileWriter(rootDirectory: root, policy: testPolicy())
        let firstRecovery = try await recoveredWriter.recover(recordingID: manifest.id)
        let secondRecovery = try await recoveredWriter.recover(recordingID: manifest.id)

        let store = try JSONRecordingManifestStore(rootDirectory: root)
        let recoveredManifest = try await store.load(recordingID: manifest.id)
        XCTAssertEqual(firstRecovery.state, .recovered)
        XCTAssertEqual(firstRecovery.recoveredChunkIDs, [chunkID])
        XCTAssertEqual(firstRecovery.manifestRewritten, true)
        XCTAssertEqual(secondRecovery.state, .valid)
        XCTAssertEqual(secondRecovery.recoveredChunkIDs, [])
        XCTAssertEqual(recoveredManifest?.chunks.map(\.id), [chunkID])
    }

    func testCrashBeforeCloseQuarantinesPartialChunkWithoutManifestAppend() async throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let writer = try ChunkFileWriter(rootDirectory: root, policy: testPolicy())
        let manifest = try await writer.createSession(
            descriptor: recordingDescriptor(),
            productPolicy: RecordingMode.meeting.defaultProductPolicy
        )

        try await writer.openChunk(recordingID: manifest.id, assetID: UUID(), sequence: 0)
        try await writer.write(Data("partial".utf8), to: manifest.id)

        let recoveredWriter = try ChunkFileWriter(rootDirectory: root, policy: testPolicy())
        let recovery = try await recoveredWriter.recover(recordingID: manifest.id)
        let store = try JSONRecordingManifestStore(rootDirectory: root)
        let recoveredManifest = try await store.load(recordingID: manifest.id)

        XCTAssertEqual(recovery.state, .needsAttention)
        XCTAssertEqual(recovery.quarantinedFileNames.count, 1)
        XCTAssertTrue(recovery.quarantinedFileNames[0].contains(".partial.quarantine"))
        XCTAssertEqual(recoveredManifest?.chunks ?? [], [])
        XCTAssertEqual(recoveredManifest?.localState, .needsAttention)
    }

    func testMissingListedChunkRequiresAttention() async throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let writer = try ChunkFileWriter(rootDirectory: root, policy: testPolicy())
        let manifest = try await writer.createSession(
            descriptor: recordingDescriptor(),
            productPolicy: RecordingMode.dailyMemory.defaultProductPolicy
        )
        let chunk = try await writeClosedChunk(writer: writer, recordingID: manifest.id)
        let chunkURL = await writer.finalizedChunkURL(
            recordingID: manifest.id,
            assetID: chunk.assetID,
            sequence: chunk.sequence,
            chunkID: chunk.id
        )
        try FileManager.default.removeItem(at: chunkURL)

        let recovery = try await writer.recover(recordingID: manifest.id)
        let store = try JSONRecordingManifestStore(rootDirectory: root)
        let recoveredManifest = try await store.load(recordingID: manifest.id)

        XCTAssertEqual(recovery.state, .needsAttention)
        XCTAssertEqual(recovery.missingChunkIDs, [chunk.id])
        XCTAssertEqual(recoveredManifest?.localState, .needsAttention)
    }

    func testChecksumMismatchQuarantinesCorruptChunk() async throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let writer = try ChunkFileWriter(rootDirectory: root, policy: testPolicy())
        let manifest = try await writer.createSession(
            descriptor: recordingDescriptor(),
            productPolicy: RecordingMode.interview.defaultProductPolicy
        )
        let chunk = try await writeClosedChunk(writer: writer, recordingID: manifest.id)
        let chunkURL = await writer.finalizedChunkURL(
            recordingID: manifest.id,
            assetID: chunk.assetID,
            sequence: chunk.sequence,
            chunkID: chunk.id
        )
        try Data("tampered".utf8).write(to: chunkURL)

        let recovery = try await writer.recover(recordingID: manifest.id)

        XCTAssertEqual(recovery.state, .needsAttention)
        XCTAssertEqual(recovery.checksumMismatchChunkIDs, [chunk.id])
        XCTAssertEqual(recovery.quarantinedFileNames.count, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: chunkURL.path))
    }

    func testCorruptedJournalTailIsReportedWithoutDiscardingValidEvents() async throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let writer = try ChunkFileWriter(rootDirectory: root, policy: testPolicy())
        let manifest = try await writer.createSession(
            descriptor: recordingDescriptor(),
            productPolicy: RecordingMode.meeting.defaultProductPolicy
        )
        _ = try await writeClosedChunk(writer: writer, recordingID: manifest.id)
        let packageURL = await writer.packageURL(recordingID: manifest.id)
        let journalURL = packageURL.appendingPathComponent("recovery-journal.jsonl")
        let handle = try FileHandle(forWritingTo: journalURL)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("{\"schemaVersion\":".utf8))
        try handle.close()

        let recovery = try await writer.recover(recordingID: manifest.id)

        XCTAssertEqual(recovery.state, .recovered)
        XCTAssertEqual(recovery.corruptJournalTailLineCount, 1)
    }

    func testInsufficientStorageFailsBeforeWritingBytes() async throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let writer = try ChunkFileWriter(
            rootDirectory: root,
            policy: testPolicy(lowStorageSafetyMarginBytes: 1_024),
            faultInjection: ChunkFileWriterFaultInjection(availableCapacityBytes: 10)
        )
        let manifest = try await writer.createSession(
            descriptor: recordingDescriptor(),
            productPolicy: RecordingMode.dictation.defaultProductPolicy
        )
        try await writer.openChunk(recordingID: manifest.id, assetID: UUID(), sequence: 0)

        do {
            try await writer.write(Data("too much".utf8), to: manifest.id)
            XCTFail("write should fail before persisting bytes")
        } catch ChunkWriterError.insufficientStorage(let required, let available) {
            XCTAssertEqual(required, 1_032)
            XCTAssertEqual(available, 10)
        }
    }

    func testInjectedWriteErrorLeavesRecoveryToQuarantinePartial() async throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let writer = try ChunkFileWriter(
            rootDirectory: root,
            policy: testPolicy(),
            faultInjection: ChunkFileWriterFaultInjection(failNextWrite: true)
        )
        let manifest = try await writer.createSession(
            descriptor: recordingDescriptor(),
            productPolicy: RecordingMode.quickThought.defaultProductPolicy
        )
        try await writer.openChunk(recordingID: manifest.id, assetID: UUID(), sequence: 0)

        do {
            try await writer.write(Data("bytes".utf8), to: manifest.id)
            XCTFail("write should fail")
        } catch ChunkWriterError.chunkWriteFailed(_) {
            let recoveredWriter = try ChunkFileWriter(rootDirectory: root, policy: testPolicy())
            let recovery = try await recoveredWriter.recover(recordingID: manifest.id)
            XCTAssertEqual(recovery.state, .needsAttention)
            XCTAssertEqual(recovery.quarantinedFileNames.count, 1)
        }
    }

    func testDuplicateSequenceIsRejectedBeforeOpeningSecondChunk() async throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let writer = try ChunkFileWriter(rootDirectory: root, policy: testPolicy())
        let manifest = try await writer.createSession(
            descriptor: recordingDescriptor(),
            productPolicy: RecordingMode.dictation.defaultProductPolicy
        )
        let chunk = try await writeClosedChunk(writer: writer, recordingID: manifest.id, sequence: 0)

        do {
            try await writer.openChunk(recordingID: manifest.id, assetID: chunk.assetID, sequence: 0)
            XCTFail("duplicate asset sequence should fail")
        } catch ChunkWriterError.invalidState(let message) {
            XCTAssertTrue(message.contains("sequence"))
        }
    }

    private func writeClosedChunk(
        writer: ChunkFileWriter,
        recordingID: UUID,
        assetID: UUID = UUID(),
        sequence: Int = 0,
        data: Data = Data("closed chunk".utf8)
    ) async throws -> AudioChunkDescriptor {
        try await writer.openChunk(recordingID: recordingID, assetID: assetID, sequence: sequence)
        try await writer.write(data, to: recordingID)
        return try await writer.closeChunk(recordingID: recordingID, durationMilliseconds: 1_000)
    }

    private func recordingDescriptor(id: UUID = UUID()) -> RecordingDescriptor {
        RecordingDescriptor(
            clientRecordingID: id,
            sourcePlatform: .macOS,
            mode: .meeting,
            startedAt: Date(timeIntervalSince1970: 10),
            localeIdentifier: "en_US"
        )
    }

    private func testPolicy(lowStorageSafetyMarginBytes: Int64 = 0) -> ChunkWriterPolicy {
        ChunkWriterPolicy(
            targetChunkDurationMilliseconds: 15_000,
            maximumChunkDurationMilliseconds: 30_000,
            maximumChunkBytes: 1_024 * 1_024,
            lowStorageSafetyMarginBytes: lowStorageSafetyMarginBytes,
            flushIntervalBytes: 4,
            checksumAlgorithm: .sha256,
            finalizedChunkExtension: "caf",
            temporaryChunkSuffix: "partial",
            chunksDirectoryName: "chunks",
            quarantineDirectoryName: "quarantine",
            journalFileName: "recovery-journal.jsonl"
        )
    }

    private func makeTemporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateChunkWriterTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        return root
    }
}
