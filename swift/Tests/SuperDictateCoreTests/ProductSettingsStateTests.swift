import Foundation
import XCTest
@testable import SuperDictateCore

extension ProductStateTests {
    func testSettingsAttentionComesOnlyFromMissingPermissionOrServiceFailure() {
        let healthy = SuperDictateSettingsSnapshot(
            primaryShortcut: "Right Command",
            triggerMode: "Hold",
            completionBehavior: "Insert",
            removeFillerWords: false,
            speechModelName: "Parakeet",
            speechModelReady: true,
            recentTranscriptMode: .last10,
            libraryRecordingCount: 12,
            serviceState: .running,
            permissions: [
                SuperDictatePermissionStatus(kind: .microphone, state: .granted),
                SuperDictatePermissionStatus(kind: .accessibility, state: .granted),
                SuperDictatePermissionStatus(kind: .inputMonitoring, state: .granted),
            ],
            appVersion: "0.2.37",
            updateState: .current(version: "0.2.37")
        )
        XCTAssertFalse(healthy.needsSystemAttention)
        XCTAssertTrue(healthy.missingPermissions.isEmpty)

        var missing = healthy
        missing.permissions[0].state = .missing
        XCTAssertTrue(missing.needsSystemAttention)
        XCTAssertEqual(missing.missingPermissions.map(\.kind), [.microphone])

        var serviceFailure = healthy
        serviceFailure.serviceState = .needsAttention
        XCTAssertTrue(serviceFailure.needsSystemAttention)
    }

    func testSettingsProjectionNormalizesOptionalLabelsAndCounts() {
        let snapshot = SuperDictateSettingsSnapshot(
            primaryShortcut: "Fn",
            alternateShortcut: "   ",
            historyShortcut: nil,
            triggerMode: "Press",
            completionBehavior: "Copy",
            removeFillerWords: true,
            speechModelName: "Local model",
            speechModelDetail: "  Local only  ",
            speechModelReady: false,
            recentTranscriptMode: .off,
            libraryRecordingCount: -10,
            serviceState: .stopped,
            permissions: [],
            appVersion: "1.0",
            updateState: .checking
        )

        XCTAssertNil(snapshot.alternateShortcut)
        XCTAssertNil(snapshot.historyShortcut)
        XCTAssertEqual(snapshot.speechModelDetail, "Local only")
        XCTAssertEqual(snapshot.libraryRecordingCount, 0)
        XCTAssertFalse(snapshot.historyEnabled)
    }

    func testRecentTranscriptModeDescribesVisibilityNotDurableRetention() {
        XCTAssertEqual(SuperDictateRecentTranscriptMode.off.visibleEntryCount, 0)
        XCTAssertEqual(SuperDictateRecentTranscriptMode.last1.visibleEntryCount, 1)
        XCTAssertEqual(SuperDictateRecentTranscriptMode.last5.visibleEntryCount, 5)
        XCTAssertEqual(SuperDictateRecentTranscriptMode.last10.visibleEntryCount, 10)

        let snapshot = SuperDictateSettingsSnapshot(
            primaryShortcut: "Right Command",
            triggerMode: "Hold",
            completionBehavior: "Insert",
            removeFillerWords: false,
            speechModelName: "Parakeet",
            speechModelReady: true,
            recentTranscriptMode: .last1,
            libraryRecordingCount: 37,
            serviceState: .running,
            permissions: [],
            appVersion: "1.0",
            updateState: .checking
        )

        XCTAssertTrue(snapshot.historyEnabled)
        XCTAssertEqual(snapshot.recentTranscriptMode.visibleEntryCount, 1)
        XCTAssertEqual(snapshot.libraryRecordingCount, 37)
    }

    func testClearTranscriptHistoryIsAnExplicitDestructiveCommand() {
        XCTAssertEqual(
            SuperDictateSettingsCommand.clearTranscriptHistory,
            .clearTranscriptHistory
        )
    }
}
