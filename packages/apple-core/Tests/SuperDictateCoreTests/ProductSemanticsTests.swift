import Foundation
import XCTest
@testable import SuperDictateCore

final class ProductSemanticsTests: XCTestCase {
    func testMeetingPolicyRequiresConsentAndProjectMemoryReview() {
        let policy = RecordingMode.meeting.defaultProductPolicy

        XCTAssertEqual(policy.sensitivity, .confidential)
        XCTAssertEqual(policy.consentRequirement, .confirmParticipantsInformed)
        XCTAssertEqual(policy.memoryScope, .project)
        XCTAssertTrue(policy.requestedArtifacts.contains(.decisions))
        XCTAssertTrue(policy.requestedArtifacts.contains(.actionItems))
        XCTAssertTrue(policy.requestedArtifacts.contains(.memoryCandidates))
        XCTAssertTrue(policy.requiresInsightReview)
        XCTAssertTrue(policy.createsPersistentMemory)
    }

    func testDictationDoesNotCreateMemory() {
        let policy = RecordingMode.dictation.defaultProductPolicy

        XCTAssertEqual(policy.memoryScope, .disabled)
        XCTAssertEqual(policy.requestedArtifacts, [.cleanedTranscript])
        XCTAssertFalse(policy.requiresInsightReview)
        XCTAssertFalse(policy.createsPersistentMemory)
    }

    func testDailyMemoryUsesPrivateSensitivity() {
        let policy = RecordingMode.dailyMemory.defaultProductPolicy

        XCTAssertEqual(policy.sensitivity, .privateContent)
        XCTAssertEqual(policy.consentRequirement, .soloNote)
        XCTAssertEqual(policy.memoryScope, .personal)
    }

    func testLocalOnlyRetentionBlocksSourceUpload() {
        var policy = RecordingMode.quickThought.defaultProductPolicy
        policy.sourceAudioRetention = .localOnly

        XCTAssertFalse(policy.canUploadSourceAudio)
    }

    func testFixedRetentionNormalizesInvalidDayCountForDisplay() {
        let retention = RetentionPolicy.fixedDays(0)

        XCTAssertEqual(retention.fixedDayCount, 1)
    }

    func testEvidenceRejectsInvalidChronology() {
        XCTAssertThrowsError(
            try EvidenceSpan(
                recordingID: UUID(),
                transcriptRevisionID: UUID(),
                startOffsetMilliseconds: 2_000,
                endOffsetMilliseconds: 1_000,
                excerpt: "Invalid"
            )
        ) { error in
            XCTAssertEqual(error as? DomainValidationError, .invalidTimeRange)
        }
    }

    func testInsightRequiresEvidence() {
        XCTAssertThrowsError(
            try ExtractedInsight(
                recordingID: UUID(),
                kind: .decision,
                statement: "Ship the first watch beta.",
                confidence: .high,
                evidence: []
            )
        ) { error in
            XCTAssertEqual(error as? DomainValidationError, .missingEvidence)
        }
    }

    func testApprovedInsightIsTrusted() throws {
        let recordingID = UUID()
        let evidence = try EvidenceSpan(
            recordingID: recordingID,
            transcriptRevisionID: UUID(),
            startOffsetMilliseconds: 100,
            endOffsetMilliseconds: 500,
            excerpt: "We decided to ship the watch beta first."
        )
        let insight = try ExtractedInsight(
            recordingID: recordingID,
            kind: .decision,
            statement: "Ship the watch beta first.",
            confidence: .medium,
            reviewState: .approved,
            evidence: [evidence]
        )

        XCTAssertTrue(insight.isUserTrusted)
    }

    func testExpiredMemoryIsNotValid() throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let memory = try MemoryCandidate(
            sourceInsightID: UUID(),
            statement: "The beta launch is scheduled for August.",
            scope: .project,
            sensitivity: .confidential,
            reviewState: .expired,
            validUntil: now.addingTimeInterval(-1)
        )

        XCTAssertFalse(memory.isValid(at: now))
    }

    func testSuggestedActionAssignmentRequiresReview() throws {
        let action = try ActionItem(
            sourceInsightID: UUID(),
            title: "Prepare the beta checklist",
            suggestedOwner: "Sergey",
            suggestedDueDate: Date(timeIntervalSince1970: 2_000)
        )

        XCTAssertTrue(action.requiresAssignmentReview)
        XCTAssertTrue(action.requiresDueDateReview)
        XCTAssertEqual(action.synchronizationState, .local)
    }
}
