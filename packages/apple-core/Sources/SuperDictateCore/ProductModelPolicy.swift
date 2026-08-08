import Foundation

public enum SuperDictateDeviceClass: String, Codable, CaseIterable, Sendable {
    case appleSiliconMac = "apple_silicon_mac"
    case intelMac = "intel_mac"
    case iPhone
    case iPad
    case appleWatch = "apple_watch"
    case unknown
}

public struct SuperDictateModelRecommendation: Identifiable, Codable, Equatable, Sendable {
    public var id: String { model.id }
    public let model: LocalAIModelDescriptor
    public let rank: Int
    public let reason: String
    public let recommended: Bool

    public init(
        model: LocalAIModelDescriptor,
        rank: Int,
        reason: String,
        recommended: Bool = true
    ) {
        self.model = model
        self.rank = max(0, rank)
        self.reason = reason
        self.recommended = recommended
    }
}

/// Product policy for choosing local models without leaking platform checks
/// throughout views and recording code.
public enum SuperDictateModelPolicy {
    public static func recommendations(
        for device: SuperDictateDeviceClass,
        capability: LocalAIModelCapability
    ) -> [SuperDictateModelRecommendation] {
        switch capability {
        case .transcription, .translation, .diarization:
            return speechRecommendations(for: device, capability: capability)
        case .summarization, .actionExtraction, .insightExtraction:
            return languageRecommendations(for: device, capability: capability)
        }
    }

    public static func preferredModel(
        for device: SuperDictateDeviceClass,
        capability: LocalAIModelCapability,
        from states: [LocalModelRuntimeState]
    ) -> LocalModelRuntimeState? {
        let ranking = Dictionary(
            uniqueKeysWithValues: recommendations(for: device, capability: capability)
                .map { ($0.model.id, $0.rank) }
        )

        return states
            .filter { $0.supports(capability) }
            .sorted { lhs, rhs in
                if lhs.isUsable != rhs.isUsable { return lhs.isUsable }
                let leftRank = ranking[lhs.model.id] ?? Int.max
                let rightRank = ranking[rhs.model.id] ?? Int.max
                if leftRank != rightRank { return leftRank < rightRank }
                return lhs.model.displayName < rhs.model.displayName
            }
            .first
    }

    private static func speechRecommendations(
        for device: SuperDictateDeviceClass,
        capability: LocalAIModelCapability
    ) -> [SuperDictateModelRecommendation] {
        let whisperCpp = model(adapter: .whisperCpp, capability: capability)
        let whisperKit = model(adapter: .whisperKit, capability: capability)

        switch device {
        case .intelMac:
            return compact([
                whisperCpp.map {
                    SuperDictateModelRecommendation(
                        model: $0,
                        rank: 0,
                        reason: "Best-supported free local CPU path for Intel Mac."
                    )
                },
                whisperKit.map {
                    SuperDictateModelRecommendation(
                        model: $0,
                        rank: 10,
                        reason: "Native Apple speech stack is not the primary Intel path.",
                        recommended: false
                    )
                },
            ])

        case .appleSiliconMac, .iPhone, .iPad:
            return compact([
                whisperKit.map {
                    SuperDictateModelRecommendation(
                        model: $0,
                        rank: 0,
                        reason: "Native Apple on-device path with the best platform acceleration potential."
                    )
                },
                whisperCpp.map {
                    SuperDictateModelRecommendation(
                        model: $0,
                        rank: 10,
                        reason: "Portable local fallback and compatibility option."
                    )
                },
            ])

        case .appleWatch:
            // The watch is optimized for immediate, reliable capture and handoff.
            // Heavy local transcription can be evaluated separately when runtime,
            // battery, storage and model constraints justify it.
            return []

        case .unknown:
            return compact([
                whisperCpp.map {
                    SuperDictateModelRecommendation(
                        model: $0,
                        rank: 0,
                        reason: "Portable local fallback when platform acceleration is unknown."
                    )
                },
                whisperKit.map {
                    SuperDictateModelRecommendation(
                        model: $0,
                        rank: 10,
                        reason: "Prefer when running on a supported Apple Neural Engine path."
                    )
                },
            ])
        }
    }

    private static func languageRecommendations(
        for device: SuperDictateDeviceClass,
        capability: LocalAIModelCapability
    ) -> [SuperDictateModelRecommendation] {
        guard device != .appleWatch else { return [] }

        let models = LocalAIModelCatalog.models(capableOf: capability)
        return models.enumerated().map { index, model in
            let builtIn = model.id == LocalAIModelCatalog.builtInRuleBased.id
            return SuperDictateModelRecommendation(
                model: model,
                rank: builtIn ? 0 : index + 10,
                reason: builtIn
                    ? "Always-available offline fallback; use a neural local model when higher quality is installed."
                    : "Optional local neural model for richer processing.",
                recommended: true
            )
        }
    }

    private static func model(
        adapter: LocalAIAdapterKind,
        capability: LocalAIModelCapability
    ) -> LocalAIModelDescriptor? {
        LocalAIModelCatalog.models(capableOf: capability)
            .first { $0.adapterKind == adapter }
    }

    private static func compact<T>(_ values: [T?]) -> [T] {
        values.compactMap { $0 }
    }
}
