import Combine
import SwiftUI
import SuperDictateCore

/// Stable observable bridge for the native Settings window.
///
/// Runtime refreshes update the snapshot/language in place rather than replacing
/// the hosting root view. This preserves the user's selected Settings section and
/// native navigation state while service, permission, model or update state changes.
@MainActor
public final class SuperDictateSettingsModel: ObservableObject {
    @Published public var snapshot: SuperDictateSettingsSnapshot
    @Published public var language: SuperDictateInterfaceLanguage

    public init(
        snapshot: SuperDictateSettingsSnapshot,
        language: SuperDictateInterfaceLanguage = .english
    ) {
        self.snapshot = snapshot
        self.language = language
    }
}

/// Live wrapper used by the macOS control-panel runtime.
@MainActor
public struct SuperDictateLiveSettingsView: View {
    @ObservedObject private var model: SuperDictateSettingsModel
    private let onCommand: (SuperDictateSettingsCommand) -> Void

    public init(
        model: SuperDictateSettingsModel,
        onCommand: @escaping (SuperDictateSettingsCommand) -> Void = { _ in }
    ) {
        self.model = model
        self.onCommand = onCommand
    }

    public var body: some View {
        SuperDictateSettingsView(
            snapshot: model.snapshot,
            language: model.language,
            onCommand: onCommand
        )
    }
}
