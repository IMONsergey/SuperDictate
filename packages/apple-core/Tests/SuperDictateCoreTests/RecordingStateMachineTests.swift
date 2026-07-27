import Foundation
import XCTest
@testable import SuperDictateCore

final class RecordingStateMachineTests: XCTestCase {
    func testCompleteRecordingLifecycle() throws {
        let startedAt = Date(timeIntervalSince1970: 100)
        let pausedAt = Date(timeIntervalSince1970: 110)
        let resumedAt = Date(timeIntervalSince1970: 120)
        var machine = RecordingStateMachine()

        try machine.send(.start(at: startedAt))
        XCTAssertEqual(machine.state, .recording(startedAt: startedAt))
        XCTAssertTrue(machine.state.isCapturingAudio)

        try machine.send(.pause(at: pausedAt))
        XCTAssertEqual(machine.state, .paused(startedAt: startedAt, pausedAt: pausedAt))
        XCTAssertFalse(machine.state.isCapturingAudio)
        XCTAssertTrue(machine.state.hasActiveSession)

        try machine.send(.resume(at: resumedAt))
        XCTAssertEqual(machine.state, .recording(startedAt: startedAt))

        try machine.send(.stop)
        XCTAssertEqual(machine.state, .finalizing)

        try machine.send(.finalized)
        XCTAssertEqual(machine.state, .awaitingUpload)

        try machine.send(.uploadStarted)
        XCTAssertEqual(machine.state, .uploading(progress: 0))

        try machine.send(.uploadProgress(0.5))
        XCTAssertEqual(machine.state, .uploading(progress: 0.5))

        try machine.send(.uploadCompleted)
        XCTAssertEqual(machine.state, .processing(.queued))

        try machine.send(.processingChanged(.transcribing))
        XCTAssertEqual(machine.state, .processing(.transcribing))

        try machine.send(.processingChanged(.structuring))
        XCTAssertEqual(machine.state, .processing(.structuring))

        try machine.send(.completed)
        XCTAssertEqual(machine.state, .ready)

        try machine.send(.reset)
        XCTAssertEqual(machine.state, .idle)
    }

    func testStopIsAllowedWhilePaused() throws {
        let startedAt = Date(timeIntervalSince1970: 100)
        let pausedAt = Date(timeIntervalSince1970: 101)
        var machine = RecordingStateMachine()

        try machine.send(.start(at: startedAt))
        try machine.send(.pause(at: pausedAt))
        try machine.send(.stop)

        XCTAssertEqual(machine.state, .finalizing)
    }

    func testUploadFailureCanRetryAtUploadBoundary() throws {
        let failure = RecordingFailure(
            code: "network_unavailable",
            message: "The upload could not start.",
            retryTarget: .upload
        )
        var machine = RecordingStateMachine(state: .awaitingUpload)

        try machine.send(.failed(failure))
        XCTAssertEqual(machine.state, .failed(failure))

        try machine.send(.retry)
        XCTAssertEqual(machine.state, .awaitingUpload)
    }

    func testProcessingFailureCanRetryAtQueueBoundary() throws {
        let failure = RecordingFailure(
            code: "worker_timeout",
            message: "The processing worker timed out.",
            retryTarget: .processing
        )
        var machine = RecordingStateMachine(state: .processing(.transcribing))

        try machine.send(.failed(failure))
        XCTAssertEqual(machine.state, .failed(failure))

        try machine.send(.retry)
        XCTAssertEqual(machine.state, .processing(.queued))
    }

    func testNonRetryableFailureRejectsRetry() throws {
        let failure = RecordingFailure(
            code: "audio_corrupt",
            message: "The audio file is invalid.",
            retryTarget: .none
        )
        var machine = RecordingStateMachine(state: .awaitingUpload)

        try machine.send(.failed(failure))

        XCTAssertThrowsError(try machine.send(.retry)) { error in
            XCTAssertTrue(error is InvalidRecordingTransition)
        }
    }

    func testInvalidProgressIsRejectedWithoutChangingState() throws {
        var machine = RecordingStateMachine(state: .uploading(progress: 0.25))

        XCTAssertThrowsError(try machine.send(.uploadProgress(1.01)))
        XCTAssertEqual(machine.state, .uploading(progress: 0.25))
    }

    func testInvalidChronologyIsRejected() throws {
        let startedAt = Date(timeIntervalSince1970: 100)
        let invalidPause = Date(timeIntervalSince1970: 99)
        var machine = RecordingStateMachine()

        try machine.send(.start(at: startedAt))

        XCTAssertThrowsError(try machine.send(.pause(at: invalidPause)))
        XCTAssertEqual(machine.state, .recording(startedAt: startedAt))
    }

    func testCannotStartTwice() throws {
        let startedAt = Date(timeIntervalSince1970: 100)
        var machine = RecordingStateMachine()

        try machine.send(.start(at: startedAt))

        XCTAssertThrowsError(try machine.send(.start(at: startedAt)))
    }
}
