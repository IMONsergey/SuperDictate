import Foundation
import XCTest
@testable import SuperDictateCore

extension ProductStateTests {
    func testSpeakerRenameDoesNotRewriteEvidenceSegment() throws {
        let recordingID = UUID()
        let segment = SuperDictateEvidenceSegment(
            text: "We should ship Friday.",
            speaker: "Speaker 1",
            startMilliseconds: 1_000,
            endMilliseconds: 2_000
        )
        let profile = SuperDictateSpeakerProfile(displayName: "Ada")
        var directory = SuperDictateSpeakerDirectory(profiles: [profile])
        try directory.assign(
            speakerProfileID: profile.id,
            recordingID: recordingID,
            segmentID: segment.id
        )

        XCTAssertEqual(
            directory.resolvedSpeakerName(recordingID: recordingID, segment: segment),
            "Ada"
        )
        try directory.renameProfile(id: profile.id, to: "Ada Lovelace")
        XCTAssertEqual(
            directory.resolvedSpeakerName(recordingID: recordingID, segment: segment),
            "Ada Lovelace"
        )
        XCTAssertEqual(segment.speaker, "Speaker 1")
        XCTAssertEqual(segment.text, "We should ship Friday.")
    }

    func testSpeakerMergeRemapsAssignmentsWithoutChangingEvidence() throws {
        let recordingID = UUID()
        let segmentID = UUID()
        let source = SuperDictateSpeakerProfile(displayName: "Ada duplicate")
        let target = SuperDictateSpeakerProfile(displayName: "Ada")
        var directory = SuperDictateSpeakerDirectory(profiles: [source, target])
        try directory.assign(
            speakerProfileID: source.id,
            recordingID: recordingID,
            segmentID: segmentID
        )

        try directory.mergeSpeaker(sourceID: source.id, into: target.id)

        XCTAssertNil(directory.profile(id: source.id))
        XCTAssertNotNil(directory.profile(id: target.id))
        XCTAssertEqual(
            directory.assignment(recordingID: recordingID, segmentID: segmentID)?.speakerProfileID,
            target.id
        )
    }

    func testSpeakerAssignmentUpsertKeepsOneMappingPerSegment() throws {
        let recordingID = UUID()
        let segmentID = UUID()
        let first = SuperDictateSpeakerProfile(displayName: "First")
        let second = SuperDictateSpeakerProfile(displayName: "Second")
        var directory = SuperDictateSpeakerDirectory(profiles: [first, second])

        try directory.assign(
            speakerProfileID: first.id,
            recordingID: recordingID,
            segmentID: segmentID
        )
        try directory.assign(
            speakerProfileID: second.id,
            recordingID: recordingID,
            segmentID: segmentID
        )

        XCTAssertEqual(directory.assignments.count, 1)
        XCTAssertEqual(directory.assignments[0].speakerProfileID, second.id)
    }

    func testRemovingRecordingAssignmentsLeavesGlobalProfiles() throws {
        let recordingID = UUID()
        let profile = SuperDictateSpeakerProfile(displayName: "Known person")
        var directory = SuperDictateSpeakerDirectory(profiles: [profile])
        try directory.assign(
            speakerProfileID: profile.id,
            recordingID: recordingID,
            segmentID: UUID()
        )

        directory.removeAssignments(recordingID: recordingID)

        XCTAssertTrue(directory.assignments.isEmpty)
        XCTAssertEqual(directory.profiles, [profile])
    }
}
