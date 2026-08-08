import Combine
import SwiftUI
import SuperDictateCore

/// Stable presentation bridge between the existing runtime adapter and SwiftUI.
/// Updating `snapshot` re-renders product content without replacing the root view,
/// so sidebar/recording selection state can survive runtime transitions.
@MainActor
public final class SuperDictateMainModel: ObservableObject {
    @Published public var snapshot: SuperDictateProductSnapshot

    public init(snapshot: SuperDictateProductSnapshot = SuperDictateProductSnapshot()) {
        self.snapshot = snapshot
    }
}

/// Live wrapper used by the macOS runtime. `SuperDictateMainView` remains a pure
/// value-driven view, while this wrapper supplies observable state over time.
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
        SuperDictateMainView(snapshot: model.snapshot, onCommand: onCommand)
    }
}
