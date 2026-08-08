import Foundation
import XCTest
@testable import SuperDictateCore

extension ProductStateTests {
    func testBuiltInSummaryTemplatesHaveStableSemanticKinds() {
        for kind in SuperDictateBuiltInSummaryTemplate.allCases {
            let template = SuperDictateBuiltInSummaryTemplates.template(kind)
            XCTAssertTrue(template.isBuiltIn)
            XCTAssertEqual(template.builtIn, kind)
            XCTAssertNil(template.customName)
        }
    }

    func testCustomSummaryTemplateRequiresNameAndCompleteSections() {
        XCTAssertThrowsError(
            try SuperDictateSummaryTemplate(
                customName: "   ",
                sections: []
            )
        ) { error in
            XCTAssertEqual(error as? SuperDictateSummaryTemplateError, .emptyName)
        }

        XCTAssertThrowsError(
            try SuperDictateSummaryTemplate(
                customName: "Client",
                sections: [
                    SuperDictateSummaryTemplateSection(
                        title: "",
                        instruction: "Summarize the client need."
                    )
                ]
            )
        ) { error in
            XCTAssertEqual(error as? SuperDictateSummaryTemplateError, .emptySection)
        }
    }

    func testCustomSummaryTemplateRoundTrips() throws {
        let source = try SuperDictateSummaryTemplate(
            customName: "Creative review",
            sections: [
                .init(title: "Decision", instruction: "Capture the decision."),
                .init(title: "Rationale", instruction: "Explain the evidence-backed rationale."),
            ],
            extractsTasks: true
        )
        let decoded = try JSONDecoder().decode(
            SuperDictateSummaryTemplate.self,
            from: JSONEncoder().encode(source)
        )
        XCTAssertEqual(decoded, source)
    }
}
