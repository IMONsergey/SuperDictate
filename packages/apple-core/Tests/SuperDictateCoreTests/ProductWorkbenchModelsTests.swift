import Foundation
import XCTest
@testable import SuperDictateCore

final class ProductWorkbenchModelsTests: XCTestCase {
    func testWorkbenchAppliesProcessingResultAndOpensProductTabs() throws {
        let recordingID = UUID()
        let transcript = try LocalTranscript(
            recordingID: recordingID,
            localeIdentifier: "ru_RU",
            modelID: "fixture.transcriber",
            segments: [
                LocalTranscriptSegment(
                    startOffsetMilliseconds: 0,
                    endOffsetMilliseconds: 2_000,
                    text: "Нужно показать красивый интерфейс."
                ),
            ]
        )
        let evidence = try transcript.evidenceSpan(for: transcript.segments[0])
        let summary = try LocalRecordingSummary(
            recordingID: recordingID,
            transcriptRevisionID: transcript.revisionID,
            modelID: LocalAIModelCatalog.builtInRuleBased.id,
            sections: [
                LocalSummarySection(
                    title: "Short summary",
                    bullets: ["Нужно показать красивый интерфейс"],
                    evidence: [evidence]
                ),
            ]
        )
        let insight = try ExtractedInsight(
            recordingID: recordingID,
            kind: .actionItem,
            statement: "Нужно показать красивый интерфейс.",
            confidence: .medium,
            evidence: [evidence]
        )
        let action = try ActionItem(
            sourceInsightID: insight.id,
            title: insight.statement
        )
        let result = LocalProcessingResult(
            recordingID: recordingID,
            transcript: transcript,
            summary: summary,
            insights: [insight],
            actionItems: [action],
            events: [],
            issues: []
        )
        var state = SuperDictateWorkbenchState()

        state.apply(result, at: Date(timeIntervalSince1970: 2_000))

        XCTAssertEqual(state.status, .needsReview)
        XCTAssertEqual(state.selectedTab, .summary)
        XCTAssertTrue(state.availableTabs.contains(.transcript))
        XCTAssertTrue(state.availableTabs.contains(.summary))
        XCTAssertTrue(state.availableTabs.contains(.actions))
        XCTAssertEqual(state.requiresReviewCount, 2)
        XCTAssertEqual(state.primaryCommand.targetTab, .actions)
    }

    func testWorkbenchTracksModelReadinessByCapability() {
        let states = [
            LocalModelRuntimeState(
                model: LocalAIModelCatalog.recommendedLocalFirst[0],
                installState: .ready,
                localStorageBytes: 100
            ),
            LocalModelRuntimeState(
                model: LocalAIModelCatalog.recommendedLocalFirst[2],
                installState: .notInstalled
            ),
        ]
        let workbench = SuperDictateWorkbenchState(modelStates: states)

        XCTAssertTrue(workbench.hasReadyModel(capableOf: .transcription))
        XCTAssertFalse(workbench.hasReadyModel(capableOf: .summarization))
        XCTAssertEqual(
            workbench.bestModel(capableOf: .transcription)?.model.adapterKind,
            .whisperCpp
        )
    }

    func testWorkbenchShowsIssuesAsNeedsAttention() {
        let issue = LocalProcessingIssue(
            recordingID: UUID(),
            stage: .summarizing,
            message: "Model failed."
        )
        let workbench = SuperDictateWorkbenchState(issues: [issue])

        XCTAssertEqual(workbench.status, .needsAttention)
        XCTAssertEqual(workbench.primaryCommand.id, "recover")
        XCTAssertTrue(workbench.badges.contains { $0.id == "issues" })
    }

    func testModelDownloadProgressIsClamped() {
        let overComplete = LocalModelRuntimeState(
            model: LocalAIModelCatalog.recommendedLocalFirst[0],
            installState: .downloading,
            downloadProgress: 1.4
        )
        let underComplete = LocalModelRuntimeState(
            model: LocalAIModelCatalog.recommendedLocalFirst[0],
            installState: .downloading,
            downloadProgress: -0.2
        )

        XCTAssertEqual(overComplete.downloadProgress, 1)
        XCTAssertEqual(underComplete.downloadProgress, 0)
    }

    func testDefaultWorkbenchEnablesRuleBasedFallbackButBlocksRecordingWithoutTranscriber() {
        let workbench = SuperDictateWorkbenchState()

        XCTAssertTrue(workbench.hasReadyModel(capableOf: .summarization))
        XCTAssertFalse(workbench.hasReadyModel(capableOf: .transcription))
        XCTAssertEqual(workbench.primaryCommand.id, "record")
        XCTAssertFalse(workbench.primaryCommand.isEnabled)
    }
}
