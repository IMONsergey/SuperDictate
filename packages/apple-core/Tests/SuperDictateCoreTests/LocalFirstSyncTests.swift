import Foundation
import XCTest
@testable import SuperDictateCore

final class LocalFirstSyncTests: XCTestCase {
    func testChunkRejectsNegativeSequence() {
        XCTAssertThrowsError(
            try AudioChunkDescriptor(
                assetID: UUID(),
                sequence: -1,
                byteCount: 10,
                durationMilliseconds: 100,
                checksum: "abc"
            )
        ) { error in
            XCTAssertEqual(error as? SyncValidationError, .negativeSequence)
        }
    }

    func testManifestAppendsChunksInSequenceOrderAndAdvancesRevision() throws {
        let descriptor = RecordingDescriptor(
            sourcePlatform: .watchOS,
            mode: .quickThought,
            startedAt: Date(timeIntervalSince1970: 100)
        )
        let assetID = UUID()
        let second = try AudioChunkDescriptor(
            assetID: assetID,
            sequence: 1,
            byteCount: 20,
            durationMilliseconds: 200,
            checksum: "second"
        )
        let first = try AudioChunkDescriptor(
            assetID: assetID,
            sequence: 0,
            byteCount: 10,
            durationMilliseconds: 100,
            checksum: "first"
        )
        var manifest = try LocalRecordingManifest(
            descriptor: descriptor,
            productPolicy: RecordingMode.quickThought.defaultProductPolicy
        )

        try manifest.appendChunk(second, at: Date(timeIntervalSince1970: 110))
        try manifest.appendChunk(first, at: Date(timeIntervalSince1970: 111))

        XCTAssertEqual(manifest.chunks.map(\.sequence), [0, 1])
        XCTAssertEqual(manifest.manifestRevision, 3)
        XCTAssertEqual(manifest.totalByteCount, 30)
        XCTAssertEqual(manifest.totalChunkDurationMilliseconds, 300)
        XCTAssertTrue(manifest.hasDurableLocalSource)
    }

    func testDuplicateChunkIdentifierIsIdempotent() throws {
        let descriptor = RecordingDescriptor(
            sourcePlatform: .iOS,
            mode: .meeting
        )
        let chunk = try AudioChunkDescriptor(
            assetID: UUID(),
            sequence: 0,
            byteCount: 100,
            durationMilliseconds: 1_000,
            checksum: "checksum"
        )
        var manifest = try LocalRecordingManifest(
            descriptor: descriptor,
            productPolicy: RecordingMode.meeting.defaultProductPolicy
        )

        try manifest.appendChunk(chunk)
        let revisionAfterFirstAppend = manifest.manifestRevision
        try manifest.appendChunk(chunk)

        XCTAssertEqual(manifest.chunks.count, 1)
        XCTAssertEqual(manifest.manifestRevision, revisionAfterFirstAppend)
    }

    func testAcknowledgementNeverRegresses() throws {
        let descriptor = RecordingDescriptor(
            sourcePlatform: .watchOS,
            mode: .quickThought
        )
        var manifest = try LocalRecordingManifest(
            descriptor: descriptor,
            productPolicy: RecordingMode.quickThought.defaultProductPolicy
        )

        manifest.advanceAcknowledgement(to: .uploadedToServer)
        let revision = manifest.manifestRevision
        manifest.advanceAcknowledgement(to: .persistedOnCompanion)

        XCTAssertEqual(manifest.acknowledgementLevel, .uploadedToServer)
        XCTAssertEqual(manifest.manifestRevision, revision)
    }

    func testEnqueueIsIdempotentForOneRecording() {
        let recordingID = UUID()
        let date = Date(timeIntervalSince1970: 100)
        var queue = UploadQueue()

        let first = queue.enqueue(
            recordingID: recordingID,
            priority: 1,
            route: .companion,
            at: date
        )
        let second = queue.enqueue(
            recordingID: recordingID,
            priority: 10,
            route: .direct,
            at: date.addingTimeInterval(1)
        )

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(first.idempotencyKey, second.idempotencyKey)
        XCTAssertEqual(queue.entries.count, 1)
    }

    func testQueueSelectsHighestPriorityEligibleEntry() {
        let date = Date(timeIntervalSince1970: 100)
        var queue = UploadQueue()
        _ = queue.enqueue(
            recordingID: UUID(),
            priority: 1,
            route: .companion,
            at: date
        )
        let highPriority = queue.enqueue(
            recordingID: UUID(),
            priority: 10,
            route: .direct,
            at: date.addingTimeInterval(1)
        )

        XCTAssertEqual(
            queue.nextEligible(at: date.addingTimeInterval(2))?.id,
            highPriority.id
        )
    }

    func testRecoverableFailureSchedulesBackoff() throws {
        let date = Date(timeIntervalSince1970: 100)
        let backoff = RetryBackoffPolicy(
            initialDelay: 5,
            multiplier: 2,
            maximumDelay: 60
        )
        var queue = UploadQueue()
        let entry = queue.enqueue(
            recordingID: UUID(),
            route: .direct,
            at: date
        )

        try queue.markStarted(entryID: entry.id, at: date)
        try queue.markFailed(
            entryID: entry.id,
            failure: SyncFailure(
                code: "timeout",
                message: "Timed out",
                classification: .recoverable
            ),
            at: date,
            backoff: backoff
        )

        let updated = try XCTUnwrap(queue.entries.first)
        XCTAssertEqual(updated.state, .waiting)
        XCTAssertEqual(updated.attemptCount, 1)
        XCTAssertEqual(updated.nextAttemptAt, date.addingTimeInterval(5))
        XCTAssertNil(queue.nextEligible(at: date.addingTimeInterval(4)))
        XCTAssertEqual(
            queue.nextEligible(at: date.addingTimeInterval(5))?.id,
            entry.id
        )
    }

    func testBackoffCapsAtMaximumDelay() {
        let backoff = RetryBackoffPolicy(
            initialDelay: 5,
            multiplier: 2,
            maximumDelay: 20
        )

        XCTAssertEqual(backoff.baseDelay(afterAttempt: 1), 5)
        XCTAssertEqual(backoff.baseDelay(afterAttempt: 2), 10)
        XCTAssertEqual(backoff.baseDelay(afterAttempt: 3), 20)
        XCTAssertEqual(backoff.baseDelay(afterAttempt: 10), 20)
    }

    func testInterruptedAttemptReturnsToWaiting() throws {
        let date = Date(timeIntervalSince1970: 100)
        var queue = UploadQueue()
        let entry = queue.enqueue(
            recordingID: UUID(),
            route: .companion,
            at: date
        )
        try queue.markStarted(entryID: entry.id, at: date)

        let recoveryDate = date.addingTimeInterval(30)
        queue.recoverInterruptedAttempts(at: recoveryDate)

        let recovered = try XCTUnwrap(queue.entries.first)
        XCTAssertEqual(recovered.state, .waiting)
        XCTAssertEqual(recovered.nextAttemptAt, recoveryDate)
        XCTAssertEqual(recovered.lastFailure?.code, "interrupted_attempt")
    }

    func testUserActionFailureCanBeUnblocked() throws {
        let date = Date(timeIntervalSince1970: 100)
        var queue = UploadQueue()
        let entry = queue.enqueue(
            recordingID: UUID(),
            route: .direct,
            at: date
        )
        try queue.markStarted(entryID: entry.id, at: date)
        try queue.markFailed(
            entryID: entry.id,
            failure: SyncFailure(
                code: "signed_out",
                message: "Sign in again",
                classification: .requiresUserAction
            ),
            at: date
        )

        XCTAssertEqual(queue.entries.first?.state, .blockedUserAction)

        let unblockedAt = date.addingTimeInterval(10)
        try queue.unblock(entryID: entry.id, at: unblockedAt)

        XCTAssertEqual(queue.entries.first?.state, .waiting)
        XCTAssertEqual(queue.entries.first?.nextAttemptAt, unblockedAt)
        XCTAssertNil(queue.entries.first?.lastFailure)
    }

    func testSuccessfulEntryPreventsDuplicateRequeue() throws {
        let date = Date(timeIntervalSince1970: 100)
        let recordingID = UUID()
        var queue = UploadQueue()
        let entry = queue.enqueue(
            recordingID: recordingID,
            route: .direct,
            at: date
        )
        try queue.markStarted(entryID: entry.id, at: date)
        try queue.markSucceeded(entryID: entry.id, at: date.addingTimeInterval(1))

        let duplicate = queue.enqueue(
            recordingID: recordingID,
            route: .companion,
            at: date.addingTimeInterval(2)
        )

        XCTAssertEqual(duplicate.id, entry.id)
        XCTAssertEqual(queue.entries.count, 1)
        XCTAssertEqual(queue.entries.first?.state, .succeeded)
    }
}
