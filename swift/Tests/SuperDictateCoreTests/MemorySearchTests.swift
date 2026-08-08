import Foundation
import XCTest
@testable import SuperDictateCore

final class MemorySearchTests: XCTestCase {
    func testLegacyRecordingProjectsIntoUntimedEvidence() {
        let recording = SuperDictateRecording(
            title: "Client call",
            transcript: "We decided to launch Friday.",
            people: ["Alex"]
        )

        let document = SuperDictateMemoryDocument(recording: recording)

        XCTAssertEqual(document.recordingID, recording.id)
        XCTAssertEqual(document.fullText, recording.transcript)
        XCTAssertEqual(document.segments.count, 1)
        XCTAssertFalse(document.segments[0].hasTimestamp)
    }

    func testExactPhraseRanksAheadOfPartialTokenMatches() {
        let exactID = UUID()
        let partialID = UUID()
        let exact = SuperDictateMemoryDocument(
            recordingID: exactID,
            title: "Exact",
            createdAt: Date(timeIntervalSince1970: 100),
            segments: [
                SuperDictateEvidenceSegment(
                    text: "Нужно подготовить коммерческое предложение до пятницы.",
                    startMilliseconds: 1_000,
                    endMilliseconds: 3_000
                ),
            ]
        )
        let partial = SuperDictateMemoryDocument(
            recordingID: partialID,
            title: "Partial",
            createdAt: Date(timeIntervalSince1970: 200),
            segments: [
                SuperDictateEvidenceSegment(
                    text: "Коммерческое направление обсудим отдельно, предложение пока не готово."
                ),
            ]
        )

        let hits = SuperDictateLocalMemoryIndex(documents: [partial, exact]).search(
            SuperDictateMemoryQuery(text: "коммерческое предложение")
        )

        XCTAssertEqual(hits.first?.recordingID, exactID)
        XCTAssertEqual(hits.first?.startMilliseconds, 1_000)
        XCTAssertGreaterThan(hits[0].score, hits[1].score)
    }

    func testSearchNormalizesCaseAndDiacritics() {
        let id = UUID()
        let document = SuperDictateMemoryDocument(
            recordingID: id,
            title: "Résumé",
            createdAt: Date(),
            people: ["Élodie"],
            tags: ["Lancement"],
            segments: [SuperDictateEvidenceSegment(text: "Discussion produit")]
        )
        let index = SuperDictateLocalMemoryIndex(documents: [document])

        XCTAssertEqual(index.matchingDocuments(text: "RESUME").first?.recordingID, id)
        XCTAssertEqual(index.matchingDocuments(text: "elodie").first?.recordingID, id)
    }

    func testRecordingScopePreventsCrossRecordingEvidenceLeakage() {
        let firstID = UUID()
        let secondID = UUID()
        let first = SuperDictateMemoryDocument(
            recordingID: firstID,
            title: "First",
            createdAt: Date(),
            segments: [SuperDictateEvidenceSegment(text: "Launch date is Monday.")]
        )
        let second = SuperDictateMemoryDocument(
            recordingID: secondID,
            title: "Second",
            createdAt: Date(),
            segments: [SuperDictateEvidenceSegment(text: "Launch date is Friday.")]
        )
        let index = SuperDictateLocalMemoryIndex(documents: [first, second])

        let hits = index.search(
            SuperDictateMemoryQuery(
                text: "launch date",
                recordingIDs: [secondID]
            )
        )

        XCTAssertEqual(hits.map(\.recordingID), [secondID])
    }

    func testRecencyBreaksEqualRelevanceTie() {
        let olderID = UUID()
        let newerID = UUID()
        let older = SuperDictateMemoryDocument(
            recordingID: olderID,
            title: "Older",
            createdAt: Date(timeIntervalSince1970: 100),
            segments: [SuperDictateEvidenceSegment(text: "Budget review complete.")]
        )
        let newer = SuperDictateMemoryDocument(
            recordingID: newerID,
            title: "Newer",
            createdAt: Date(timeIntervalSince1970: 200),
            segments: [SuperDictateEvidenceSegment(text: "Budget review complete.")]
        )

        let hits = SuperDictateLocalMemoryIndex(documents: [older, newer]).search(
            SuperDictateMemoryQuery(text: "budget review")
        )

        XCTAssertEqual(hits.map(\.recordingID), [newerID, olderID])
    }

    func testDuplicateDocumentIdentityKeepsNewestProjection() {
        let id = UUID()
        let older = SuperDictateMemoryDocument(
            recordingID: id,
            title: "Old projection",
            createdAt: Date(timeIntervalSince1970: 100),
            segments: [SuperDictateEvidenceSegment(text: "old")]
        )
        let newer = SuperDictateMemoryDocument(
            recordingID: id,
            title: "New projection",
            createdAt: Date(timeIntervalSince1970: 200),
            segments: [SuperDictateEvidenceSegment(text: "new")]
        )

        let index = SuperDictateLocalMemoryIndex(documents: [older, newer])

        XCTAssertEqual(index.documents.count, 1)
        XCTAssertEqual(index.documents.first?.title, "New projection")
    }

    func testGroundedAnswerCannotExistWithoutEvidence() {
        XCTAssertThrowsError(
            try SuperDictateMemoryAnswer(
                text: "Friday.",
                status: .grounded,
                citations: []
            )
        ) { error in
            XCTAssertEqual(error as? SuperDictateMemoryAnswerError, .groundedWithoutEvidence)
        }
    }

    func testGroundedAnswerCarriesTimestampedCitation() throws {
        let document = SuperDictateMemoryDocument(
            recordingID: UUID(),
            title: "Release",
            createdAt: Date(),
            segments: [
                SuperDictateEvidenceSegment(
                    text: "We decided to release Friday.",
                    speaker: "Alex",
                    startMilliseconds: 12_000,
                    endMilliseconds: 18_000
                ),
            ]
        )
        let hit = try XCTUnwrap(
            SuperDictateLocalMemoryIndex(documents: [document]).search(
                SuperDictateMemoryQuery(text: "release Friday")
            ).first
        )
        let answer = try SuperDictateMemoryAnswer(
            text: "The release was set for Friday.",
            status: .grounded,
            citations: [hit],
            modelID: "fixture"
        )

        XCTAssertEqual(answer.citations.first?.startMilliseconds, 12_000)
        XCTAssertEqual(answer.citations.first?.speaker, "Alex")
    }

    func testResultCapClampsToFiftyAndEmptyQueryReturnsNothing() {
        let documents = (0..<60).map { index in
            SuperDictateMemoryDocument(
                recordingID: UUID(),
                title: "Recording \(index)",
                createdAt: Date(timeIntervalSince1970: TimeInterval(index)),
                segments: [SuperDictateEvidenceSegment(text: "shared keyword \(index)")]
            )
        }
        let index = SuperDictateLocalMemoryIndex(documents: documents)

        XCTAssertTrue(index.search(SuperDictateMemoryQuery(text: "   ")).isEmpty)
        XCTAssertEqual(
            index.search(SuperDictateMemoryQuery(text: "shared keyword", maximumResults: 500)).count,
            50
        )
    }
}
