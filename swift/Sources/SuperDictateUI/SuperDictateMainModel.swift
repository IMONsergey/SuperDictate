import Combine
import SwiftUI
import SuperDictateCore

/// Stable presentation bridge between the existing runtime adapter and SwiftUI.
/// Updating published product data re-renders content without replacing the root
/// view, so sidebar/recording/search state survives runtime transitions.
@MainActor
public final class SuperDictateMainModel: ObservableObject {
    @Published public var snapshot: SuperDictateProductSnapshot
    @Published public var memoryDocuments: [SuperDictateMemoryDocument]
    @Published public var language: SuperDictateInterfaceLanguage

    public init(
        snapshot: SuperDictateProductSnapshot = SuperDictateProductSnapshot(),
        memoryDocuments: [SuperDictateMemoryDocument] = [],
        language: SuperDictateInterfaceLanguage = .english
    ) {
        self.snapshot = snapshot
        self.memoryDocuments = memoryDocuments
        self.language = language
    }
}

/// Live wrapper used by the macOS runtime. `SuperDictateMainView` remains a pure
/// value-driven view while this wrapper supplies observable state over time.
@MainActor
public struct SuperDictateLiveMainView: View {
    @ObservedObject private var model: SuperDictateMainModel
    private let onCommand: (SuperDictateCommand) -> Void

    public init(
        model: SuperDictateMainModel,
        onCommand: @escaping (SuperDictateCommand) -> Void = { _ in }
    ) {
        self.model = model
        self.onCommand = onCommand
    }

    public var body: some View {
        SuperDictateMainView(
            snapshot: model.snapshot,
            memoryDocuments: model.memoryDocuments,
            language: model.language,
            onCommand: onCommand
        )
    }
}
