import Foundation
import XCTest
@testable import SuperDictateCore

extension ProductStateTests {
    func testGroundedSummarySectionRequiresEvidence() {
        XCTAssertThrowsError(
            try SuperDictateGroundedSummarySection(
                title: "Decision",
                text: "Ship the product",
                citations: []
            )
        ) { error in
            XCTAssertEqual(
                error as? SuperDictateGroundedGenerationError,
                .missingEvidence
            )
        }
    }

    func testGroundedTaskProposalRequiresEvidence() {
        XCTAssertThrowsError(
            try SuperDictateGroundedTaskProposal(
                title: "Send follow-up",
                citations: []
            )
        ) { error in
            XCTAssertEqual(
                error as? SuperDictateGroundedGenerationError,
                .missingEvidence
            )
        }
    }

    func testEvidenceCitationPreservesSourceIdentityAndTiming() throws {
        let recordingID = UUID()
        let segment = SuperDictateEvidenceSegment(
            text: "Decision: ship Friday",
            speaker: "Ada",
            startMilliseconds: 1_200,
            endMilliseconds: 2_400
        )
        let citation = SuperDictateEvidenceCitation(
            recordingID: recordingID,
            segment: segment
        )

        XCTAssertEqual(citation.recordingID, recordingID)
        XCTAssertEqual(citation.segmentID, segment.id)
        XCTAssertEqual(citation.excerpt, "Decision: ship Friday")
        XCTAssertEqual(citation.speaker, "Ada")
        XCTAssertTrue(citation.hasTimestamp)

        let section = try SuperDictateGroundedSummarySection(
            title: "Decision",
            text: "The team plans to ship Friday.",
            citations: [citation]
        )
        let summary = try SuperDictateGroundedSummary(
            sections: [section],
            modelID: "local/test"
        )
        XCTAssertEqual(summary.sections.first?.citations.first, citation)
    }

    func testGroundedSummaryRejectsEmptySectionList() {
        XCTAssertThrowsError(
            try SuperDictateGroundedSummary(sections: [], modelID: "local/test")
        ) { error in
            XCTAssertEqual(
                error as? SuperDictateGroundedGenerationError,
                .emptyResult
            )
        }
    }
}
