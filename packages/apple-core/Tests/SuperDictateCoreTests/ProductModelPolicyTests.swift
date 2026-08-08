import XCTest
@testable import SuperDictateCore

final class ProductModelPolicyTests: XCTestCase {
    func testIntelPrefersWhisperCppForTranscription() throws {
        let recommendations = SuperDictateModelPolicy.recommendations(
            for: .intelMac,
            capability: .transcription
        )

        let first = try XCTUnwrap(recommendations.first)
        XCTAssertEqual(first.model.adapterKind, .whisperCpp)
        XCTAssertTrue(first.recommended)
    }

    func testAppleSiliconPrefersWhisperKitForTranscription() throws {
        let recommendations = SuperDictateModelPolicy.recommendations(
            for: .appleSiliconMac,
            capability: .transcription
        )

        let first = try XCTUnwrap(recommendations.first)
        XCTAssertEqual(first.model.adapterKind, .whisperKit)
        XCTAssertTrue(first.recommended)
    }

    func testWatchDoesNotAdvertiseHeavyLocalSpeechOrLanguageModels() {
        XCTAssertTrue(
            SuperDictateModelPolicy.recommendations(
                for: .appleWatch,
                capability: .transcription
            ).isEmpty
        )
        XCTAssertTrue(
            SuperDictateModelPolicy.recommendations(
                for: .appleWatch,
                capability: .summarization
            ).isEmpty
        )
    }

    func testPreferredModelUsesReadinessBeforeRecommendationRank() throws {
        let whisperCpp = try XCTUnwrap(
            LocalAIModelCatalog.recommendedLocalFirst.first { $0.adapterKind == .whisperCpp }
        )
        let whisperKit = try XCTUnwrap(
            LocalAIModelCatalog.recommendedLocalFirst.first { $0.adapterKind == .whisperKit }
        )
        let states = [
            LocalModelRuntimeState(model: whisperKit, installState: .notInstalled),
            LocalModelRuntimeState(model: whisperCpp, installState: .ready),
        ]

        let preferred = SuperDictateModelPolicy.preferredModel(
            for: .appleSiliconMac,
            capability: .transcription,
            from: states
        )

        XCTAssertEqual(preferred?.model.adapterKind, .whisperCpp)
    }

    func testBuiltInRulesRemainFirstLanguageFallback() throws {
        let recommendations = SuperDictateModelPolicy.recommendations(
            for: .intelMac,
            capability: .summarization
        )

        XCTAssertEqual(recommendations.first?.model.id, LocalAIModelCatalog.builtInRuleBased.id)
        XCTAssertEqual(recommendations.first?.rank, 0)
    }
}
