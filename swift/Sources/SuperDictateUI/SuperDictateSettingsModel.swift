import Combine
import SwiftUI
import SuperDictateCore

/// Stable observable bridge for the native Settings window.
/// Runtime refreshes update snapshot/language in place instead of replacing the
/// hosting root, preserving section selection and native navigation state.
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
