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
            historyRetention: .last10,
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
            historyRetention: .off,
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

    func testHistoryRetentionIsTypedAndBounded() {
        XCTAssertEqual(SuperDictateHistoryRetention.off.maximumEntryCount, 0)
        XCTAssertEqual(SuperDictateHistoryRetention.last1.maximumEntryCount, 1)
        XCTAssertEqual(SuperDictateHistoryRetention.last5.maximumEntryCount, 5)
        XCTAssertEqual(SuperDictateHistoryRetention.last10.maximumEntryCount, 10)

        let snapshot = SuperDictateSettingsSnapshot(
            primaryShortcut: "Right Command",
            triggerMode: "Hold",
            completionBehavior: "Insert",
            removeFillerWords: false,
            speechModelName: "Parakeet",
            speechModelReady: true,
            historyRetention: .last5,
            libraryRecordingCount: 5,
            serviceState: .running,
            permissions: [],
            appVersion: "1.0",
            updateState: .checking
        )
        XCTAssertTrue(snapshot.historyEnabled)
        XCTAssertEqual(snapshot.historyRetention, .last5)
    }

    func testClearHistoryCommandIsExplicitlyDestructiveAcrossCaches() {
        let command = SuperDictateSettingsCommand.clearTranscriptHistory
        XCTAssertEqual(command, .clearTranscriptHistory)
    }
}
