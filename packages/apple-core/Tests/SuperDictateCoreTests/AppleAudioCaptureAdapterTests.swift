import Foundation
import XCTest
@testable import SuperDictateCore

final class AppleAudioCaptureAdapterTests: XCTestCase {
    func testStartRequestsPermissionBeforeActivatingSession() {
        var coordinator = AppleAudioCaptureCoordinator(permission: .notDetermined)

        let effects = coordinator.handle(.startRequested)

        XCTAssertEqual(coordinator.state, .awaitingPermission)
        XCTAssertEqual(effects, [.requestPermission])
    }

    func testGrantedPermissionStartsChunkedRecording() {
        var coordinator = AppleAudioCaptureCoordinator(
            state: .awaitingPermission,
            permission: .notDetermined
        )

        let effects = coordinator.handle(.permissionResolved(.granted))

        XCTAssertEqual(coordinator.state, .recording)
        XCTAssertEqual(effects, [.activateSession, .beginChunkedRecording])
    }

    func testDeniedPermissionSurfacesFailure() {
        var coordinator = AppleAudioCaptureCoordinator(permission: .denied)

        let effects = coordinator.handle(.startRequested)

        XCTAssertEqual(coordinator.state, .failed)
        XCTAssertEqual(effects, [.surfaceFailure(.permissionDenied)])
    }

    func testPauseAndResumeAreExplicitRecordingTransitions() {
        var coordinator = AppleAudioCaptureCoordinator(permission: .granted)
        _ = coordinator.handle(.startRequested)

        let pauseEffects = coordinator.handle(.pauseRequested)
        let resumeEffects = coordinator.handle(.resumeRequested)

        XCTAssertEqual(pauseEffects, [.pauseEngine])
        XCTAssertEqual(resumeEffects, [.resumeEngine])
        XCTAssertEqual(coordinator.state, .recording)
    }

    func testInterruptionResumesOnlyWhenSystemAllowsAndRecordingWasActive() {
        var coordinator = AppleAudioCaptureCoordinator(permission: .granted)
        _ = coordinator.handle(.startRequested)

        let beginEffects = coordinator.handle(.interruptionBegan)
        let endEffects = coordinator.handle(.interruptionEnded(shouldResume: true))

        XCTAssertEqual(beginEffects, [.pauseEngine])
        XCTAssertEqual(endEffects, [.activateSession, .resumeEngine])
        XCTAssertEqual(coordinator.state, .recording)
    }

    func testInterruptionFromPausedStateDoesNotResumeRecording() {
        var coordinator = AppleAudioCaptureCoordinator(permission: .granted)
        _ = coordinator.handle(.startRequested)
        _ = coordinator.handle(.pauseRequested)

        _ = coordinator.handle(.interruptionBegan)
        let effects = coordinator.handle(.interruptionEnded(shouldResume: true))

        XCTAssertEqual(effects, [])
        XCTAssertEqual(coordinator.state, .paused)
    }

    func testRouteChangesAreRecordedWithoutLeavingRecordingState() {
        var coordinator = AppleAudioCaptureCoordinator(permission: .granted)
        _ = coordinator.handle(.startRequested)

        let effects = coordinator.handle(.routeChanged(.oldDeviceUnavailable))

        XCTAssertEqual(coordinator.state, .recording)
        XCTAssertEqual(coordinator.routeChangeCount, 1)
        XCTAssertEqual(effects, [.refreshRoute(.oldDeviceUnavailable)])
    }

    func testStopFinalizesWriterThenDeactivatesSession() {
        var coordinator = AppleAudioCaptureCoordinator(permission: .granted)
        _ = coordinator.handle(.startRequested)

        let stopEffects = coordinator.handle(.stopRequested)
        let finalizedEffects = coordinator.handle(.writerFinalized)

        XCTAssertEqual(coordinator.state, .ready)
        XCTAssertEqual(stopEffects, [.stopEngine, .finalizeRecording])
        XCTAssertEqual(finalizedEffects, [.deactivateSession])
    }

    func testMarkerRequiresActiveRecordingStateAndNonNegativeOffset() {
        var coordinator = AppleAudioCaptureCoordinator(permission: .granted)

        let idleEffects = coordinator.handle(
            .markerRequested(kind: .task, offsetMilliseconds: 100, note: "Later")
        )
        _ = coordinator.handle(.startRequested)
        let recordingEffects = coordinator.handle(
            .markerRequested(kind: .task, offsetMilliseconds: 100, note: "Later")
        )
        let invalidOffsetEffects = coordinator.handle(
            .markerRequested(kind: .important, offsetMilliseconds: -1, note: nil)
        )

        XCTAssertEqual(idleEffects, [.surfaceFailure(.invalidState)])
        XCTAssertEqual(
            recordingEffects,
            [.emitMarker(kind: .task, offsetMilliseconds: 100, note: "Later")]
        )
        XCTAssertEqual(invalidOffsetEffects, [.surfaceFailure(.invalidMarkerOffset)])
    }
}
