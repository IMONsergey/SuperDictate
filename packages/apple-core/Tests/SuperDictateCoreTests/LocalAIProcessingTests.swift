import Foundation
import XCTest
@testable import SuperDictateCore

final class LocalAIProcessingTests: XCTestCase {
    func testPipelineProducesSummaryInsightsAndActionsFromLocalTranscript() async throws {
        let recordingID = UUID()
        let manifest = try makeManifest(
            recordingID: recordingID,
            policy: RecordingMode.meeting.defaultProductPolicy
        )
        let transcriber = try FixtureLocalTranscriber(
            segments: [
                LocalTranscriptSegment(
                    startOffsetMilliseconds: 0,
                    endOffsetMilliseconds: 2_000,
                    speakerID: "sergey",
                    text: "We decided to ship the local recorder first.",
                    confidence: 0.91
                ),
                LocalTranscriptSegment(
                    startOffsetMilliseconds: 2_100,
                    endOffsetMilliseconds: 4_000,
                    speakerID: "sergey",
                    text: "Нужно подготовить красивый интерфейс и обработчики.",
                    confidence: 0.88
                ),
                LocalTranscriptSegment(
                    startOffsetMilliseconds: 4_100,
                    endOffsetMilliseconds: 6_000,
                    speakerID: "sergey",
                    text: "Главный риск - потерять локальные файлы при сбое.",
                    confidence: 0.86
                ),
            ]
        )
        let pipeline = LocalAIProcessingPipeline(
            transcriber: transcriber,
            now: { Date(timeIntervalSince1970: 1_000) }
        )

        let result = try await pipeline.process(manifest)

        XCTAssertEqual(result.recordingID, recordingID)
        XCTAssertEqual(result.transcript.segments.count, 3)
        XCTAssertNotNil(result.summary)
        XCTAssertTrue(result.insights.contains { $0.kind == .decision })
        XCTAssertTrue(result.insights.contains { $0.kind == .actionItem })
        XCTAssertTrue(result.insights.contains { $0.kind == .risk })
        XCTAssertEqual(result.actionItems.count, 1)
        XCTAssertEqual(result.issues, [])
        XCTAssertEqual(
            result.events.map(\.stage),
            [
                .validatingSource,
                .transcribing,
                .structuring,
                .summarizing,
                .extractingActions,
                .completed,
            ]
        )
    }

    func testDictationPolicySkipsSummaryAndInsightExtraction() async throws {
        let manifest = try makeManifest(
            policy: RecordingMode.dictation.defaultProductPolicy
        )
        let transcriber = try FixtureLocalTranscriber(
            segments: [
                LocalTranscriptSegment(
                    startOffsetMilliseconds: 0,
                    endOffsetMilliseconds: 1_000,
                    text: "Plain dictation should only produce cleaned transcript input."
                ),
            ]
        )
        let pipeline = LocalAIProcessingPipeline(transcriber: transcriber)

        let result = try await pipeline.process(manifest)

        XCTAssertNil(result.summary)
        XCTAssertEqual(result.insights, [])
        XCTAssertEqual(result.actionItems, [])
        XCTAssertFalse(result.events.map(\.stage).contains(.summarizing))
        XCTAssertFalse(result.events.map(\.stage).contains(.extractingActions))
    }

    func testSummaryFailureKeepsTranscriptAndRecordsIssue() async throws {
        let manifest = try makeManifest(
            policy: RecordingMode.quickThought.defaultProductPolicy
        )
        let transcriber = try FixtureLocalTranscriber(
            segments: [
                LocalTranscriptSegment(
                    startOffsetMilliseconds: 0,
                    endOffsetMilliseconds: 1_000,
                    text: "Нужно подготовить локальную обработку и показать результат."
                ),
            ]
        )
        let pipeline = LocalAIProcessingPipeline(
            transcriber: transcriber,
            summarizer: FailingLocalSummaryGenerator()
        )

        let result = try await pipeline.process(manifest)

        XCTAssertEqual(result.transcript.segments.count, 1)
        XCTAssertNil(result.summary)
        XCTAssertEqual(result.issues.map(\.stage), [.summarizing])
        XCTAssertEqual(result.actionItems.count, 1)
    }

    func testPipelineRejectsManifestWithoutDurableAudio() async throws {
        let recordingID = UUID()
        let descriptor = RecordingDescriptor(
            clientRecordingID: recordingID,
            sourcePlatform: .iOS,
            mode: .meeting,
            localeIdentifier: "ru_RU"
        )
        let manifest = try LocalRecordingManifest(
            descriptor: descriptor,
            productPolicy: RecordingMode.meeting.defaultProductPolicy,
            localState: .finalized,
            chunks: []
        )
        let pipeline = LocalAIProcessingPipeline(
            transcriber: FixtureLocalTranscriber(segments: [])
        )

        do {
            _ = try await pipeline.process(manifest)
            XCTFail("Expected local processing to reject a manifest with no chunks.")
        } catch {
            XCTAssertEqual(
                error as? LocalAIProcessingError,
                .missingDurableAudio(recordingID)
            )
        }
    }

    func testModelCatalogContainsFreeLocalTranscriptionAndSummaryCandidates() {
        let transcriptionModels = LocalAIModelCatalog.models(capableOf: .transcription)
        let summaryModels = LocalAIModelCatalog.models(capableOf: .summarization)

        XCTAssertTrue(transcriptionModels.contains { $0.adapterKind == .whisperCpp })
        XCTAssertTrue(transcriptionModels.contains { $0.adapterKind == .whisperKit })
        XCTAssertTrue(summaryModels.contains { $0.adapterKind == .ruleBased })
        XCTAssertTrue(summaryModels.contains { $0.adapterKind == .llamaCpp })
    }

    func testTranscriptSegmentRejectsInvalidChronology() {
        XCTAssertThrowsError(
            try LocalTranscriptSegment(
                startOffsetMilliseconds: 2_000,
                endOffsetMilliseconds: 1_000,
                text: "Invalid"
            )
        ) { error in
            XCTAssertEqual(error as? DomainValidationError, .invalidTimeRange)
        }
    }

    private func makeManifest(
        recordingID: UUID = UUID(),
        policy: RecordingProductPolicy
    ) throws -> LocalRecordingManifest {
        let descriptor = RecordingDescriptor(
            clientRecordingID: recordingID,
            sourcePlatform: .iOS,
            mode: .meeting,
            localeIdentifier: "ru_RU"
        )
        let chunk = try AudioChunkDescriptor(
            assetID: UUID(),
            sequence: 0,
            byteCount: 16_384,
            durationMilliseconds: 6_000,
            checksum: "sha256:fixture",
            persistenceState: .verified
        )

        return try LocalRecordingManifest(
            descriptor: descriptor,
            productPolicy: policy,
            localState: .finalized,
            chunks: [chunk]
        )
    }
}

private struct FailingLocalSummaryGenerator: LocalTranscriptSummarizing {
    let model = LocalAIModelCatalog.builtInRuleBased

    func summarize(_ request: LocalSummaryRequest) async throws -> LocalRecordingSummary {
        throw LocalAIProcessingError.emptySummary
    }
}

private struct FixtureLocalTranscriber: LocalAudioTranscribing {
    let model: LocalAIModelDescriptor
    let segments: [LocalTranscriptSegment]

    init(
        model: LocalAIModelDescriptor = LocalAIModelDescriptor(
            id: "fixture.transcriber",
            displayName: "Fixture transcriber",
            adapterKind: .custom,
            capabilities: [.transcription],
            licenseSummary: "Test fixture.",
            requiresNetworkDownload: false
        ),
        segments: [LocalTranscriptSegment]
    ) {
        self.model = model
        self.segments = segments
    }

    func transcribe(_ request: LocalTranscriptionRequest) async throws -> LocalTranscript {
        LocalTranscript(
            recordingID: request.manifest.id,
            localeIdentifier: request.localeIdentifier,
            modelID: model.id,
            segments: segments,
            createdAt: Date(timeIntervalSince1970: 900)
        )
    }
}
