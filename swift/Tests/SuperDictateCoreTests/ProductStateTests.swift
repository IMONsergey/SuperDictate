import Foundation
import XCTest
@testable import SuperDictateCore

final class ProductStateTests: XCTestCase {
    func testPrimaryNavigationStaysSmall() {
        XCTAssertEqual(
            SuperDictateDestination.allCases,
            [.today, .library, .tasks, .ask]
        )
    }

    func testCaptureIsCommandNotDestination() {
        let idle = SuperDictateProductSnapshot(status: .idle)
        XCTAssertEqual(idle.primaryCaptureCommand, .startRecording)

        let recording = SuperDictateProductSnapshot(
            status: .recording,
            activeRecordingStartedAt: Date()
        )
        XCTAssertEqual(recording.primaryCaptureCommand, .stopRecording)
    }

    func testSnapshotOrdersRecentRecordingsNewestFirst() {
        let old = SuperDictateRecording(
            title: "Old",
            transcript: "old",
            createdAt: Date(timeIntervalSince1970: 10)
        )
        let newest = SuperDictateRecording(
            title: "Newest",
            transcript: "new",
            createdAt: Date(timeIntervalSince1970: 20)
        )

        let snapshot = SuperDictateProductSnapshot(recordings: [old, newest])
        XCTAssertEqual(snapshot.recordings.map(\.title), ["Newest", "Old"])
    }

    func testTodaySeparatesAttentionAndActionableWork() {
        let healthy = SuperDictateRecording(title: "Healthy", transcript: "ok")
        let attention = SuperDictateRecording(
            title: "Recover me",
            transcript: "",
            requiresAttention: true
        )
        let openTask = SuperDictateTask(title: "Follow up")
        let doneTask = SuperDictateTask(title: "Done", isCompleted: true)

        let snapshot = SuperDictateProductSnapshot(
            recordings: [healthy, attention],
            tasks: [openTask, doneTask]
        )

        XCTAssertEqual(snapshot.attentionRecordings.map(\.id), [attention.id])
        XCTAssertEqual(snapshot.actionableTasks.map(\.id), [openTask.id])
    }

    func testRecentListIsBounded() {
        let recordings = (0..<12).map { index in
            SuperDictateRecording(
                title: "Recording \(index)",
                transcript: "text",
                createdAt: Date(timeIntervalSince1970: TimeInterval(index))
            )
        }

        let snapshot = SuperDictateProductSnapshot(recordings: recordings)
        XCTAssertEqual(snapshot.recentRecordings.count, 8)
        XCTAssertEqual(snapshot.recentRecordings.first?.title, "Recording 11")
    }
}
