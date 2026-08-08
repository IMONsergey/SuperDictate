import Foundation
import XCTest
@testable import SuperDictateCore

final class ProductMemorySearchTests: XCTestCase {
    func testExactPhraseRanksAbovePartialTokenMatches() throws {
        let exactID = UUID()
        let partialID = UUID()
        let exact = LocalTranscript(
            recordingID: exactID,
            localeIdentifier: "ru_RU",
            modelID: "fixture",
            segments: [
                try LocalTranscriptSegment(
                    startOffsetMilliseconds: 1_000,
                    endOffsetMilliseconds: 2_000,
                    text: "Нужно подготовить коммерческое предложение до пятницы."
                ),
            ],
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let partial = LocalTranscript(
            recordingID: partialID,
            localeIdentifier: "ru_RU",
            modelID: "fixture",
            segments: [
                try LocalTranscriptSegment(
                    startOffsetMilliseconds: 0,
                    endOffsetMilliseconds: 1_000,
                    text: "Коммерческое направление обсудим отдельно, предложение пока не готово."
                ),
            ],
            createdAt: Date(timeIntervalSince1970: 200)
        )

        let hits = SuperDictateLocalMemoryIndex(transcripts: [partial, exact]).search(
            SuperDictateMemoryQuery(text: "коммерческое предложение")
        )

        XCTAssertEqual(hits.first?.recordingID, exactID)
        XCTAssertGreaterThan(hits[0].score, hits[1].score)
        XCTAssertEqual(hits.first?.startOffsetMilliseconds, 1_000)
    }

    func testSearchIsCaseAndDiacriticInsensitive() throws {
        let recordingID = UUID()
        let transcript = LocalTranscript(
            recordingID: recordingID,
            localeIdentifier: "fr_FR",
            modelID: "fixture",
            segments: [
                try LocalTranscriptSegment(
                    startOffsetMilliseconds: 0,
                    endOffsetMilliseconds: 1_000,
                    text: "Résumé avec Élodie sur le lancement."
                ),
            ]
        )
        let index = SuperDictateLocalMemoryIndex(transcripts: [transcript])

        XCTAssertEqual(
            index.search(SuperDictateMemoryQuery(text: "RESUME ELODIE")).first?.recordingID,
            recordingID
        )
    }

    func testRecordingScopePreventsCrossRecordingLeakage() throws {
        let firstID = UUID()
        let secondID = UUID()
        let first = LocalTranscript(
            recordingID: firstID,
            localeIdentifier: "en_US",
            modelID: "fixture",
            segments: [
                try LocalTranscriptSegment(
                    startOffsetMilliseconds: 0,
                    endOffsetMilliseconds: 1_000,
                    text: "Launch date is Monday."
                ),
            ]
        )
        let second = LocalTranscript(
            recordingID: secondID,
            localeIdentifier: "en_US",
            modelID: "fixture",
            segments: [
                try LocalTranscriptSegment(
                    startOffsetMilliseconds: 0,
                    endOffsetMilliseconds: 1_000,
                    text: "Launch date is Friday."
                ),
            ]
        )
        let index = SuperDictateLocalMemoryIndex(transcripts: [first, second])

        let hits = index.search(
            SuperDictateMemoryQuery(
                text: "launch date",
                recordingIDs: [secondID]
            )
        )

        XCTAssertEqual(hits.map(\.recordingID), [secondID])
    }

    func testRecencyBreaksEqualRelevanceTies() throws {
        let olderID = UUID()
        let newerID = UUID()
        let older = LocalTranscript(
            recordingID: olderID,
            localeIdentifier: "en_US",
            modelID: "fixture",
            segments: [
                try LocalTranscriptSegment(
                    startOffsetMilliseconds: 0,
                    endOffsetMilliseconds: 1_000,
                    text: "Budget review complete."
                ),
            ],
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let newer = LocalTranscript(
            recordingID: newerID,
            localeIdentifier: "en_US",
            modelID: "fixture",
            segments: [
                try LocalTranscriptSegment(
                    startOffsetMilliseconds: 0,
                    endOffsetMilliseconds: 1_000,
                    text: "Budget review complete."
                ),
            ],
            createdAt: Date(timeIntervalSince1970: 200)
        )

        let hits = SuperDictateLocalMemoryIndex(transcripts: [older, newer]).search(
            SuperDictateMemoryQuery(text: "budget review")
        )

        XCTAssertEqual(hits.map(\.recordingID), [newerID, olderID])
    }

    func testMaximumResultsIsClampedAndEmptyQueryReturnsNothing() throws {
        let transcripts = try (0..<60).map { index -> LocalTranscript in
            LocalTranscript(
                recordingID: UUID(),
                localeIdentifier: "en_US",
                modelID: "fixture",
                segments: [
                    try LocalTranscriptSegment(
                        startOffsetMilliseconds: 0,
                        endOffsetMilliseconds: 1_000,
                        text: "shared keyword \(index)"
                    ),
                ],
                createdAt: Date(timeIntervalSince1970: TimeInterval(index))
            )
        }
        let index = SuperDictateLocalMemoryIndex(transcripts: transcripts)

        XCTAssertTrue(index.search(SuperDictateMemoryQuery(text: "   ")).isEmpty)
        XCTAssertEqual(
            index.search(
                SuperDictateMemoryQuery(text: "shared keyword", maximumResults: 500)
            ).count,
            50
        )
    }
}
