import Foundation
import XCTest
@testable import SuperDictateCore

final class ProductMemoryAnswerTests: XCTestCase {
    func testGroundedAnswerRequiresCitation() {
        XCTAssertThrowsError(
            try SuperDictateMemoryAnswer(
                query: SuperDictateMemoryQuery(text: "What did we decide?"),
                text: "We decided to ship Friday.",
                status: .grounded,
                citations: []
            )
        ) { error in
            XCTAssertEqual(
                error as? SuperDictateMemoryAnswerValidationError,
                .groundedAnswerWithoutCitations
            )
        }
    }

    func testCitationPreservesExactRecordingAndTimestamp() throws {
        let recordingID = UUID()
        let hit = SuperDictateMemorySearchHit(
            recordingID: recordingID,
            transcriptRevisionID: UUID(),
            segmentID: UUID(),
            startOffsetMilliseconds: 12_000,
            endOffsetMilliseconds: 18_000,
            speakerID: "speaker-1",
            excerpt: "We decided to ship Friday.",
            score: 20,
            transcriptCreatedAt: Date(timeIntervalSince1970: 100)
        )
        let citation = try SuperDictateMemoryCitation(searchHit: hit)
        let answer = try SuperDictateMemoryAnswer(
            query: SuperDictateMemoryQuery(text: "What did we decide?"),
            text: "The release was set for Friday.",
            status: .grounded,
            citations: [citation],
            modelID: "fixture.model"
        )

        XCTAssertEqual(answer.status, .grounded)
        XCTAssertEqual(answer.citations.first?.recordingID, recordingID)
        XCTAssertEqual(answer.citations.first?.startOffsetMilliseconds, 12_000)
        XCTAssertEqual(answer.citations.first?.endOffsetMilliseconds, 18_000)
        XCTAssertEqual(answer.citations.first?.excerpt, hit.excerpt)
    }

    func testInsufficientEvidenceIsExplicitAndMayHaveNoCitations() throws {
        let query = SuperDictateMemoryQuery(text: "What did Alex promise?")
        let answer = try SuperDictateMemoryAnswer.insufficientEvidence(for: query)

        XCTAssertEqual(answer.status, .insufficientEvidence)
        XCTAssertTrue(answer.citations.isEmpty)
        XCTAssertFalse(answer.text.isEmpty)
    }

    func testEmptyAnswerIsRejected() {
        XCTAssertThrowsError(
            try SuperDictateMemoryAnswer(
                query: SuperDictateMemoryQuery(text: "Anything?"),
                text: "   ",
                status: .insufficientEvidence,
                citations: []
            )
        ) { error in
            XCTAssertEqual(
                error as? SuperDictateMemoryAnswerValidationError,
                .emptyAnswer
            )
        }
    }
}
