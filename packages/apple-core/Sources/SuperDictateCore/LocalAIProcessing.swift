import Foundation

public enum LocalAIProcessingError: Error, Equatable, Sendable {
    case missingDurableAudio(UUID)
    case emptyTranscript(UUID)
    case emptySummary
    case unavailableModel(String)
}

public enum LocalAIModelCapability: String, Codable, CaseIterable, Hashable, Sendable {
    case transcription
    case translation
    case diarization
    case summarization
    case actionExtraction = "action_extraction"
    case insightExtraction = "insight_extraction"
}

public enum LocalAIAdapterKind: String, Codable, CaseIterable, Sendable {
    case ruleBased = "rule_based"
    case whisperCpp = "whisper_cpp"
    case whisperKit = "whisperkit"
    case llamaCpp = "llama_cpp"
    case mlx
    case custom
}

public struct LocalAIModelDescriptor: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let adapterKind: LocalAIAdapterKind
    public let capabilities: Set<LocalAIModelCapability>
    public let repositoryURL: String?
    public let licenseSummary: String
    public let approximateDiskBytes: Int64?
    public let requiresNetworkDownload: Bool
    public let notes: String

    public init(
        id: String,
        displayName: String,
        adapterKind: LocalAIAdapterKind,
        capabilities: Set<LocalAIModelCapability>,
        repositoryURL: String? = nil,
        licenseSummary: String,
        approximateDiskBytes: Int64? = nil,
        requiresNetworkDownload: Bool = true,
        notes: String = ""
    ) {
        self.id = id
        self.displayName = displayName
        self.adapterKind = adapterKind
        self.capabilities = capabilities
        self.repositoryURL = repositoryURL
        self.licenseSummary = licenseSummary
        self.approximateDiskBytes = approximateDiskBytes
        self.requiresNetworkDownload = requiresNetworkDownload
        self.notes = notes
    }
}

public enum LocalAIModelCatalog {
    public static let builtInRuleBased = LocalAIModelDescriptor(
        id: "superdictate.rule-based.v1",
        displayName: "SuperDictate local rules",
        adapterKind: .ruleBased,
        capabilities: [.summarization, .actionExtraction, .insightExtraction],
        licenseSummary: "Bundled application code.",
        requiresNetworkDownload: false,
        notes: "Offline fallback for summaries, actions and review queues before a neural model is installed."
    )

    public static let recommendedLocalFirst: [LocalAIModelDescriptor] = [
        LocalAIModelDescriptor(
            id: "whisper.cpp.tiny-base-small",
            displayName: "whisper.cpp tiny/base/small",
            adapterKind: .whisperCpp,
            capabilities: [.transcription, .translation],
            repositoryURL: "https://github.com/ggml-org/whisper.cpp",
            licenseSummary: "Engine is MIT; selected model/checkpoint license must be verified at install time.",
            approximateDiskBytes: 466 * 1_024 * 1_024,
            notes: "Best first adapter for free offline transcription on macOS and iOS-capable builds."
        ),
        LocalAIModelDescriptor(
            id: "argmax.whisperkit",
            displayName: "Argmax OSS / WhisperKit",
            adapterKind: .whisperKit,
            capabilities: [.transcription, .diarization],
            repositoryURL: "https://github.com/argmaxinc/whisperkit",
            licenseSummary: "SDK is MIT with third-party notices; selected model license must be verified.",
            notes: "Native Swift path for on-device Apple Silicon speech AI."
        ),
        LocalAIModelDescriptor(
            id: "llama.cpp.local-instruct",
            displayName: "llama.cpp local instruct runner",
            adapterKind: .llamaCpp,
            capabilities: [.summarization, .actionExtraction, .insightExtraction],
            repositoryURL: "https://github.com/ggml-org/llama.cpp",
            licenseSummary: "Runner is MIT; selected GGUF model license must be verified.",
            notes: "Adapter slot for local summaries, structured extraction and Ask SuperDictate."
        ),
        LocalAIModelDescriptor(
            id: "qwen2.5-7b-instruct.gguf",
            displayName: "Qwen2.5 7B Instruct via llama.cpp",
            adapterKind: .llamaCpp,
            capabilities: [.summarization, .actionExtraction, .insightExtraction],
            repositoryURL: "https://huggingface.co/Qwen/Qwen2.5-7B",
            licenseSummary: "Apache 2.0 for the referenced model card; quantized distribution must be verified.",
            notes: "Good local summarization candidate for machines with enough memory."
        ),
    ]

    public static func models(
        capableOf capability: LocalAIModelCapability
    ) -> [LocalAIModelDescriptor] {
        ([builtInRuleBased] + recommendedLocalFirst).filter { descriptor in
            descriptor.capabilities.contains(capability)
        }
    }
}

public struct LocalTranscriptSegment: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let startOffsetMilliseconds: Int64
    public let endOffsetMilliseconds: Int64
    public let speakerID: String?
    public let text: String
    public let confidence: Double?

    public init(
        id: UUID = UUID(),
        startOffsetMilliseconds: Int64,
        endOffsetMilliseconds: Int64,
        speakerID: String? = nil,
        text: String,
        confidence: Double? = nil
    ) throws {
        guard startOffsetMilliseconds >= 0, endOffsetMilliseconds >= 0 else {
            throw DomainValidationError.negativeOffset
        }
        guard endOffsetMilliseconds >= startOffsetMilliseconds else {
            throw DomainValidationError.invalidTimeRange
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainValidationError.emptyStatement
        }

        self.id = id
        self.startOffsetMilliseconds = startOffsetMilliseconds
        self.endOffsetMilliseconds = endOffsetMilliseconds
        self.speakerID = speakerID
        self.text = text
        self.confidence = confidence
    }
}

public struct LocalTranscript: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let recordingID: UUID
    public let revisionID: UUID
    public let localeIdentifier: String
    public let modelID: String
    public let segments: [LocalTranscriptSegment]
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        recordingID: UUID,
        revisionID: UUID = UUID(),
        localeIdentifier: String,
        modelID: String,
        segments: [LocalTranscriptSegment],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.recordingID = recordingID
        self.revisionID = revisionID
        self.localeIdentifier = localeIdentifier
        self.modelID = modelID
        self.segments = segments.sorted { lhs, rhs in
            lhs.startOffsetMilliseconds < rhs.startOffsetMilliseconds
        }
        self.createdAt = createdAt
    }

    public var fullText: String {
        segments.map(\.text).joined(separator: "\n")
    }

    public var durationMilliseconds: Int64 {
        segments.map(\.endOffsetMilliseconds).max() ?? 0
    }

    public func evidenceSpan(for segment: LocalTranscriptSegment) throws -> EvidenceSpan {
        try EvidenceSpan(
            recordingID: recordingID,
            transcriptRevisionID: revisionID,
            startOffsetMilliseconds: segment.startOffsetMilliseconds,
            endOffsetMilliseconds: segment.endOffsetMilliseconds,
            speakerID: segment.speakerID,
            excerpt: segment.text
        )
    }
}

public struct LocalTranscriptionRequest: Codable, Equatable, Sendable {
    public let manifest: LocalRecordingManifest
    public let preferredModelID: String?
    public let localeIdentifier: String
    public let glossary: [String]

    public init(
        manifest: LocalRecordingManifest,
        preferredModelID: String? = nil,
        localeIdentifier: String? = nil,
        glossary: [String] = []
    ) {
        self.manifest = manifest
        self.preferredModelID = preferredModelID
        self.localeIdentifier = localeIdentifier ?? manifest.descriptor.localeIdentifier
        self.glossary = glossary
    }
}

public struct LocalSummarySection: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let bullets: [String]
    public let evidence: [EvidenceSpan]

    public init(
        id: UUID = UUID(),
        title: String,
        bullets: [String],
        evidence: [EvidenceSpan]
    ) throws {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !bullets.isEmpty else {
            throw LocalAIProcessingError.emptySummary
        }

        self.id = id
        self.title = title
        self.bullets = bullets
        self.evidence = evidence
    }
}

public struct LocalRecordingSummary: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let recordingID: UUID
    public let transcriptRevisionID: UUID
    public let modelID: String
    public let sections: [LocalSummarySection]
    public let generatedAt: Date

    public init(
        id: UUID = UUID(),
        recordingID: UUID,
        transcriptRevisionID: UUID,
        modelID: String,
        sections: [LocalSummarySection],
        generatedAt: Date = Date()
    ) throws {
        guard !sections.isEmpty else {
            throw LocalAIProcessingError.emptySummary
        }

        self.id = id
        self.recordingID = recordingID
        self.transcriptRevisionID = transcriptRevisionID
        self.modelID = modelID
        self.sections = sections
        self.generatedAt = generatedAt
    }
}

public struct LocalSummaryRequest: Codable, Equatable, Sendable {
    public let manifest: LocalRecordingManifest
    public let transcript: LocalTranscript
    public let requestedArtifacts: Set<ProcessingArtifact>
    public let maximumBullets: Int

    public init(
        manifest: LocalRecordingManifest,
        transcript: LocalTranscript,
        requestedArtifacts: Set<ProcessingArtifact>? = nil,
        maximumBullets: Int = 6
    ) {
        self.manifest = manifest
        self.transcript = transcript
        self.requestedArtifacts = requestedArtifacts ?? manifest.productPolicy.requestedArtifacts
        self.maximumBullets = max(1, maximumBullets)
    }
}

public struct LocalInsightExtractionRequest: Codable, Equatable, Sendable {
    public let manifest: LocalRecordingManifest
    public let transcript: LocalTranscript
    public let requestedArtifacts: Set<ProcessingArtifact>

    public init(
        manifest: LocalRecordingManifest,
        transcript: LocalTranscript,
        requestedArtifacts: Set<ProcessingArtifact>? = nil
    ) {
        self.manifest = manifest
        self.transcript = transcript
        self.requestedArtifacts = requestedArtifacts ?? manifest.productPolicy.requestedArtifacts
    }
}

public protocol LocalAudioTranscribing: Sendable {
    var model: LocalAIModelDescriptor { get }
    func transcribe(_ request: LocalTranscriptionRequest) async throws -> LocalTranscript
}

public protocol LocalTranscriptSummarizing: Sendable {
    var model: LocalAIModelDescriptor { get }
    func summarize(_ request: LocalSummaryRequest) async throws -> LocalRecordingSummary
}

public protocol LocalInsightExtracting: Sendable {
    var model: LocalAIModelDescriptor { get }
    func extractInsights(_ request: LocalInsightExtractionRequest) async throws -> [ExtractedInsight]
}

public struct UnavailableLocalTranscriber: LocalAudioTranscribing {
    public let model: LocalAIModelDescriptor

    public init(model: LocalAIModelDescriptor) {
        self.model = model
    }

    public func transcribe(_ request: LocalTranscriptionRequest) async throws -> LocalTranscript {
        throw LocalAIProcessingError.unavailableModel(model.id)
    }
}

public struct RuleBasedLocalSummaryGenerator: LocalTranscriptSummarizing {
    public let model = LocalAIModelCatalog.builtInRuleBased

    public init() {}

    public func summarize(_ request: LocalSummaryRequest) async throws -> LocalRecordingSummary {
        guard !request.transcript.segments.isEmpty else {
            throw LocalAIProcessingError.emptyTranscript(request.transcript.recordingID)
        }

        let evidence = try request.transcript.segments.prefix(3).map { segment in
            try request.transcript.evidenceSpan(for: segment)
        }
        let bullets = Self.extractiveBullets(
            from: request.transcript.fullText,
            maximumCount: request.maximumBullets
        )
        guard !bullets.isEmpty else {
            throw LocalAIProcessingError.emptySummary
        }

        let title: String
        if request.requestedArtifacts.contains(.detailedSummary) {
            title = "Detailed summary"
        } else {
            title = "Short summary"
        }

        let section = try LocalSummarySection(
            title: title,
            bullets: bullets,
            evidence: evidence
        )
        return try LocalRecordingSummary(
            recordingID: request.manifest.id,
            transcriptRevisionID: request.transcript.revisionID,
            modelID: model.id,
            sections: [section]
        )
    }

    private static func extractiveBullets(
        from text: String,
        maximumCount: Int
    ) -> [String] {
        let separators = CharacterSet(charactersIn: ".!?\n")
        var seen: Set<String> = []
        var bullets: [String] = []
        let sentences = text
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for sentence in sentences {
            let key = sentence.lowercased()
            guard !seen.contains(key) else {
                continue
            }
            seen.insert(key)
            bullets.append(sentence)
            if bullets.count == maximumCount {
                break
            }
        }

        return bullets
    }
}

public struct RuleBasedLocalInsightExtractor: LocalInsightExtracting {
    public let model = LocalAIModelCatalog.builtInRuleBased

    public init() {}

    public func extractInsights(
        _ request: LocalInsightExtractionRequest
    ) async throws -> [ExtractedInsight] {
        var insights: [ExtractedInsight] = []
        var seenKeys: Set<String> = []

        for segment in request.transcript.segments {
            guard let kind = Self.classify(segment.text),
                  request.requestedArtifacts.contains(Self.artifact(for: kind)) else {
                continue
            }

            let statement = Self.normalizedStatement(segment.text)
            let key = "\(kind.rawValue):\(statement.lowercased())"
            guard !seenKeys.contains(key) else {
                continue
            }

            let evidence = try request.transcript.evidenceSpan(for: segment)
            let insight = try ExtractedInsight(
                recordingID: request.manifest.id,
                kind: kind,
                statement: statement,
                confidence: .medium,
                evidence: [evidence]
            )
            insights.append(insight)
            seenKeys.insert(key)
        }

        return insights
    }

    private static func classify(_ text: String) -> InsightKind? {
        let value = text.lowercased()

        if containsAny(value, [
            "решили", "решено", "фиксируем решение", "we decided", "decision is",
        ]) {
            return .decision
        }
        if containsAny(value, [
            "нужно", "надо", "задача", "сделать", "подготовить", "дедлайн",
            "todo", "to do", "need to", "action item", "follow up",
        ]) {
            return .actionItem
        }
        if containsAny(value, [
            "обещаю", "беру на себя", "я сделаю", "мы сделаем", "i will", "we will",
        ]) {
            return .commitment
        }
        if value.contains("?") || containsAny(value, ["вопрос", "question"]) {
            return .openQuestion
        }
        if containsAny(value, [
            "риск", "блокер", "проблема", "мешает", "risk", "blocker", "blocked",
        ]) {
            return .risk
        }
        if containsAny(value, [
            "исправить", "поправить", "заменить", "корректировка", "correction", "change",
        ]) {
            return .clientCorrection
        }

        return nil
    }

    private static func artifact(for kind: InsightKind) -> ProcessingArtifact {
        switch kind {
        case .decision:
            return .decisions
        case .actionItem:
            return .actionItems
        case .commitment:
            return .commitments
        case .openQuestion:
            return .openQuestions
        case .risk:
            return .risks
        case .clientCorrection:
            return .clientCorrections
        case .factCandidate:
            return .memoryCandidates
        case .notableMoment:
            return .keyQuotes
        }
    }

    private static func containsAny(_ value: String, _ needles: [String]) -> Bool {
        needles.contains { value.contains($0) }
    }

    private static func normalizedStatement(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
    }
}

public enum LocalProcessingJobState: String, Codable, CaseIterable, Sendable {
    case waiting
    case running
    case succeeded
    case failedRecoverable = "failed_recoverable"
    case failedPermanent = "failed_permanent"
}

public enum LocalAIProcessingStage: String, Codable, CaseIterable, Sendable {
    case validatingSource = "validating_source"
    case transcribing
    case structuring
    case summarizing
    case extractingActions = "extracting_actions"
    case completed
}

public struct LocalProcessingJob: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let recordingID: UUID
    public var requestedArtifacts: Set<ProcessingArtifact>
    public var state: LocalProcessingJobState
    public var currentStage: LocalAIProcessingStage?
    public var attemptCount: Int
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        recordingID: UUID,
        requestedArtifacts: Set<ProcessingArtifact>,
        state: LocalProcessingJobState = .waiting,
        currentStage: LocalAIProcessingStage? = nil,
        attemptCount: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.recordingID = recordingID
        self.requestedArtifacts = requestedArtifacts
        self.state = state
        self.currentStage = currentStage
        self.attemptCount = max(0, attemptCount)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct LocalProcessingEvent: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let recordingID: UUID
    public let stage: LocalAIProcessingStage
    public let message: String
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        recordingID: UUID,
        stage: LocalAIProcessingStage,
        message: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.recordingID = recordingID
        self.stage = stage
        self.message = message
        self.createdAt = createdAt
    }
}

public struct LocalProcessingIssue: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let recordingID: UUID
    public let stage: LocalAIProcessingStage
    public let message: String

    public init(
        id: UUID = UUID(),
        recordingID: UUID,
        stage: LocalAIProcessingStage,
        message: String
    ) {
        self.id = id
        self.recordingID = recordingID
        self.stage = stage
        self.message = message
    }
}

public struct LocalProcessingResult: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let recordingID: UUID
    public let transcript: LocalTranscript
    public let summary: LocalRecordingSummary?
    public let insights: [ExtractedInsight]
    public let actionItems: [ActionItem]
    public let events: [LocalProcessingEvent]
    public let issues: [LocalProcessingIssue]
    public let completedAt: Date

    public init(
        id: UUID = UUID(),
        recordingID: UUID,
        transcript: LocalTranscript,
        summary: LocalRecordingSummary?,
        insights: [ExtractedInsight],
        actionItems: [ActionItem],
        events: [LocalProcessingEvent],
        issues: [LocalProcessingIssue],
        completedAt: Date = Date()
    ) {
        self.id = id
        self.recordingID = recordingID
        self.transcript = transcript
        self.summary = summary
        self.insights = insights
        self.actionItems = actionItems
        self.events = events
        self.issues = issues
        self.completedAt = completedAt
    }
}

public actor LocalAIProcessingPipeline {
    private let transcriber: any LocalAudioTranscribing
    private let summarizer: any LocalTranscriptSummarizing
    private let insightExtractor: any LocalInsightExtracting
    private let now: @Sendable () -> Date

    public init(
        transcriber: any LocalAudioTranscribing,
        summarizer: any LocalTranscriptSummarizing = RuleBasedLocalSummaryGenerator(),
        insightExtractor: any LocalInsightExtracting = RuleBasedLocalInsightExtractor(),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.transcriber = transcriber
        self.summarizer = summarizer
        self.insightExtractor = insightExtractor
        self.now = now
    }

    public func process(_ manifest: LocalRecordingManifest) async throws -> LocalProcessingResult {
        guard manifest.hasDurableLocalSource else {
            throw LocalAIProcessingError.missingDurableAudio(manifest.id)
        }

        var events: [LocalProcessingEvent] = []
        var issues: [LocalProcessingIssue] = []

        appendEvent(
            .validatingSource,
            "Validated local chunk package.",
            recordingID: manifest.id,
            events: &events
        )
        appendEvent(
            .transcribing,
            "Started local transcription.",
            recordingID: manifest.id,
            events: &events
        )
        let transcript = try await transcriber.transcribe(
            LocalTranscriptionRequest(manifest: manifest)
        )
        guard !transcript.segments.isEmpty else {
            throw LocalAIProcessingError.emptyTranscript(manifest.id)
        }

        appendEvent(
            .structuring,
            "Structured transcript evidence.",
            recordingID: manifest.id,
            events: &events
        )

        var summary: LocalRecordingSummary?
        if manifest.productPolicy.requestedArtifacts.needsSummary {
            do {
                appendEvent(
                    .summarizing,
                    "Generated local summary.",
                    recordingID: manifest.id,
                    events: &events
                )
                summary = try await summarizer.summarize(
                    LocalSummaryRequest(manifest: manifest, transcript: transcript)
                )
            } catch {
                issues.append(
                    LocalProcessingIssue(
                        recordingID: manifest.id,
                        stage: .summarizing,
                        message: String(describing: error)
                    )
                )
            }
        }

        var insights: [ExtractedInsight] = []
        if manifest.productPolicy.requestedArtifacts.needsInsightExtraction {
            do {
                appendEvent(
                    .extractingActions,
                    "Extracted local insight candidates.",
                    recordingID: manifest.id,
                    events: &events
                )
                insights = try await insightExtractor.extractInsights(
                    LocalInsightExtractionRequest(manifest: manifest, transcript: transcript)
                )
            } catch {
                issues.append(
                    LocalProcessingIssue(
                        recordingID: manifest.id,
                        stage: .extractingActions,
                        message: String(describing: error)
                    )
                )
            }
        }

        let actionItems = insights.compactMap { insight -> ActionItem? in
            guard insight.kind == .actionItem else {
                return nil
            }
            return try? ActionItem(
                sourceInsightID: insight.id,
                title: insight.statement
            )
        }

        appendEvent(
            .completed,
            "Completed local processing.",
            recordingID: manifest.id,
            events: &events
        )

        return LocalProcessingResult(
            recordingID: manifest.id,
            transcript: transcript,
            summary: summary,
            insights: insights,
            actionItems: actionItems,
            events: events,
            issues: issues,
            completedAt: now()
        )
    }

    private func appendEvent(
        _ stage: LocalAIProcessingStage,
        _ message: String,
        recordingID: UUID,
        events: inout [LocalProcessingEvent]
    ) {
        events.append(
            LocalProcessingEvent(
                recordingID: recordingID,
                stage: stage,
                message: message,
                createdAt: now()
            )
        )
    }
}

private extension Set where Element == ProcessingArtifact {
    var needsSummary: Bool {
        contains(.shortSummary)
            || contains(.detailedSummary)
            || contains(.topicChapters)
            || contains(.followUpDraft)
            || contains(.projectBriefUpdate)
    }

    var needsInsightExtraction: Bool {
        contains(.decisions)
            || contains(.actionItems)
            || contains(.commitments)
            || contains(.openQuestions)
            || contains(.risks)
            || contains(.clientCorrections)
            || contains(.memoryCandidates)
            || contains(.keyQuotes)
    }
}
