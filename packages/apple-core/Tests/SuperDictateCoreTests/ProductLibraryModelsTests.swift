import Foundation
import XCTest
@testable import SuperDictateCore

final class ProductLibraryModelsTests: XCTestCase {
    func testLibraryItemNormalizesUserFacingMetadata() {
        let item = SuperDictateLibraryItem(
            id: UUID(),
            title: "   ",
            createdAt: Date(timeIntervalSince1970: 10),
            durationMilliseconds: -100,
            previewText: "   ",
            people: [" Сергей ", "сергей", "", "Anna"],
            tags: [" Client ", "client", "Meeting"],
            taskCount: -2,
            requiresReviewCount: -4
        )

        XCTAssertEqual(item.title, "Untitled recording")
        XCTAssertEqual(item.durationMilliseconds, 0)
        XCTAssertNil(item.previewText)
        XCTAssertEqual(item.people, ["Сергей", "Anna"])
        XCTAssertEqual(item.tags, ["Client", "Meeting"])
        XCTAssertEqual(item.taskCount, 0)
        XCTAssertEqual(item.requiresReviewCount, 0)
    }

    func testLibraryProjectionKeepsProductStateWithoutTechnicalInternals() throws {
        let recordingID = UUID()
        let transcript = LocalTranscript(
            recordingID: recordingID,
            localeIdentifier: "ru_RU",
            modelID: "fixture.transcriber",
            segments: [
                try LocalTranscriptSegment(
                    startOffsetMilliseconds: 0,
                    endOffsetMilliseconds: 3_000,
                    text: "Обсудили следующий релиз SuperDictate."
                ),
            ],
            createdAt: Date(timeIntervalSince1970: 1_000)
        )
        let evidence = try transcript.evidenceSpan(for: transcript.segments[0])
        let insight = try ExtractedInsight(
            recordingID: recordingID,
            kind: .actionItem,
            statement: "Подготовить следующий релиз.",
            confidence: .medium,
            evidence: [evidence]
        )
        let action = try ActionItem(sourceInsightID: insight.id, title: insight.statement)
        let workbench = SuperDictateWorkbenchState(
            transcript: transcript,
            insights: [insight],
            actionItems: [action]
        )

        let item = try XCTUnwrap(
            SuperDictateLibraryItem.projecting(workbench, title: "Release review")
        )

        XCTAssertEqual(item.id, recordingID)
        XCTAssertEqual(item.title, "Release review")
        XCTAssertEqual(item.createdAt, transcript.createdAt)
        XCTAssertEqual(item.durationMilliseconds, 3_000)
        XCTAssertEqual(item.previewText, transcript.fullText)
        XCTAssertEqual(item.state, .needsReview)
        XCTAssertEqual(item.taskCount, 1)
        XCTAssertEqual(item.requiresReviewCount, 2)
        XCTAssertTrue(item.hasTranscript)
        XCTAssertFalse(item.hasSummary)
    }

    func testLibrarySearchIsCaseAndDiacriticInsensitiveAcrossMetadata() {
        let now = Date(timeIntervalSince1970: 3_000)
        let items = [
            SuperDictateLibraryItem(
                id: UUID(),
                title: "Résumé discussion",
                createdAt: now,
                previewText: "Product planning",
                people: ["Élodie"],
                tags: ["Client"]
            ),
            SuperDictateLibraryItem(
                id: UUID(),
                title: "Другая встреча",
                createdAt: now.addingTimeInterval(-60),
                previewText: "Бюджет"
            ),
        ]
        let snapshot = SuperDictateLibrarySnapshot(items: items)

        XCTAssertEqual(snapshot.results(query: "resume").map(\.title), ["Résumé discussion"])
        XCTAssertEqual(snapshot.results(query: "ELODIE").map(\.title), ["Résumé discussion"])
        XCTAssertEqual(snapshot.results(query: "client").map(\.title), ["Résumé discussion"])
    }

    func testLibraryFiltersAttentionAndSortsDeterministically() {
        let base = Date(timeIntervalSince1970: 10_000)
        let ready = SuperDictateLibraryItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            title: "Ready",
            createdAt: base,
            durationMilliseconds: 1_000,
            state: .ready
        )
        let review = SuperDictateLibraryItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            title: "Review",
            createdAt: base.addingTimeInterval(-60),
            durationMilliseconds: 8_000,
            state: .needsReview
        )
        let failed = SuperDictateLibraryItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            title: "Failed",
            createdAt: base.addingTimeInterval(-120),
            durationMilliseconds: 4_000,
            state: .failed
        )
        let snapshot = SuperDictateLibrarySnapshot(items: [failed, ready, review])

        XCTAssertEqual(snapshot.results().map(\.title), ["Ready", "Review", "Failed"])
        XCTAssertEqual(snapshot.results(sort: .longestFirst).map(\.title), ["Review", "Failed", "Ready"])
        XCTAssertEqual(snapshot.needsAttention.map(\.title), ["Review", "Failed"])
    }
}
