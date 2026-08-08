import SwiftUI
import SuperDictateCore

/// Native Settings v2 surface over the existing runtime settings/service model.
/// The view never persists settings or controls the service directly; mutations
/// leave through `SuperDictateSettingsCommand` so tested runtime handlers remain
/// authoritative during migration away from the legacy control panel.
public struct SuperDictateSettingsView: View {
    private let snapshot: SuperDictateSettingsSnapshot
    private let language: SuperDictateInterfaceLanguage
    private let onCommand: (SuperDictateSettingsCommand) -> Void

    @State private var section: SuperDictateSettingsSection = .dictation
    @State private var confirmClearHistory = false

    public init(
        snapshot: SuperDictateSettingsSnapshot,
        language: SuperDictateInterfaceLanguage = .english,
        onCommand: @escaping (SuperDictateSettingsCommand) -> Void = { _ in }
    ) {
        self.snapshot = snapshot
        self.language = language
        self.onCommand = onCommand
    }

    public var body: some View {
        NavigationSplitView {
            List(SuperDictateSettingsSection.allCases, selection: $section) { item in
                Label(sectionTitle(item), systemImage: sectionSymbol(item))
                    .tag(item)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 240)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.section) {
                    Text(sectionTitle(section))
                        .font(SuperDictateDesign.TypeStyle.display)
                    sectionContent
                }
                .padding(SuperDictateDesign.Spacing.contentGutter)
                .frame(maxWidth: 680, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .background(SuperDictateDesign.ColorRole.canvas)
        }
        .frame(minWidth: 760, minHeight: 520)
        .confirmationDialog(
            text("Очистить историю?", "Clear History?"),
            isPresented: $confirmClearHistory,
            titleVisibility: .visible
        ) {
            Button(text("Очистить историю", "Clear History"), role: .destructive) {
                onCommand(.clearTranscriptHistory)
            }
            Button(text("Отмена", "Cancel"), role: .cancel) {}
        } message: {
            Text(text(
                "Будут удалены локальный список недавних диктовок и Library. Новые диктовки снова начнут сохраняться, если режим не выключен.",
                "The local recent-dictation cache and Library will be cleared. New dictations will be stored again unless history is Off."
            ))
        }
    }

    private var copy: SuperDictateCopy { SuperDictateCopy(language: language) }

    @ViewBuilder
    private var sectionContent: some View {
        switch section {
        case .dictation: dictationSection
        case .models: modelsSection
        case .privacy: privacySection
        case .system: systemSection
        }
    }

    private var dictationSection: some View {
        SettingsGroup {
            SettingsValueRow(
                title: text("Основная комбинация", "Primary shortcut"),
                value: snapshot.primaryShortcut
            )
            if let alternate = snapshot.alternateShortcut {
                SettingsValueRow(
                    title: text("Альтернативное завершение", "Alternate completion"),
                    value: alternate
                )
            }
            if let history = snapshot.historyShortcut {
                SettingsValueRow(
                    title: text("История", "History shortcut"),
                    value: history
                )
            }
            SettingsValueRow(
                title: text("Режим запуска", "Trigger mode"),
                value: snapshot.triggerMode
            )
            SettingsValueRow(
                title: text("После диктовки", "Completion behavior"),
                value: snapshot.completionBehavior
            )
            Toggle(
                text("Убирать слова-паразиты", "Remove filler words"),
                isOn: Binding(
                    get: { snapshot.removeFillerWords },
                    set: { onCommand(.setRemoveFillerWords($0)) }
                )
            )
            Button(text("Изменить комбинации…", "Edit shortcuts…")) {
                onCommand(.editShortcuts)
            }
        }
    }

    /// Model state is deliberately read-only until the native model manager is
    /// backed by the existing tested runtime switch/download path. A disabled or
    /// fake "Manage" button would overstate current capability.
    private var modelsSection: some View {
        SettingsGroup {
            HStack(alignment: .top, spacing: SuperDictateDesign.Spacing.component) {
                VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.micro) {
                    Text(snapshot.speechModelName)
                        .font(SuperDictateDesign.TypeStyle.interfaceMedium)
                    if let detail = snapshot.speechModelDetail {
                        Text(detail)
                            .font(SuperDictateDesign.TypeStyle.caption)
                            .foregroundStyle(SuperDictateDesign.ColorRole.textSecondary)
                    }
                }
                Spacer()
                Label(
                    snapshot.speechModelReady
                        ? text("Готова", "Ready")
                        : text("Не готова", "Not ready"),
                    systemImage: snapshot.speechModelReady
                        ? "checkmark.circle.fill"
                        : "arrow.down.circle"
                )
                .font(SuperDictateDesign.TypeStyle.caption)
                .foregroundStyle(
                    snapshot.speechModelReady
                        ? SuperDictateDesign.ColorRole.success
                        : SuperDictateDesign.ColorRole.textSecondary
                )
            }

            Text(text(
                "Модель речи — системная настройка. Управление моделью появится здесь только после подключения нативного менеджера к текущему runtime.",
                "The speech model is a system setting. Model controls will appear here only after the native manager is connected to the current runtime."
            ))
            .font(SuperDictateDesign.TypeStyle.caption)
            .foregroundStyle(SuperDictateDesign.ColorRole.textSecondary)
        }
    }

    private var privacySection: some View {
        SettingsGroup {
            HStack {
                Text(text("Недавние диктовки", "Recent dictations"))
                Spacer()
                Picker(
                    "",
                    selection: Binding(
                        get: { snapshot.recentTranscriptMode },
                        set: { onCommand(.setRecentTranscriptMode($0)) }
                    )
                ) {
                    ForEach(SuperDictateRecentTranscriptMode.allCases) { mode in
                        Text(recentModeTitle(mode)).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 170)
            }

            SettingsValueRow(
                title: text("Записей в библиотеке", "Library recordings"),
                value: String(snapshot.libraryRecordingCount)
            )

            Label(
                text(
                    "1 / 5 / 10 управляет только быстрым списком недавних. Локальная Library может хранить более ранние записи. «Не сохранять» отключает историю и очищает локальный индекс.",
                    "1 / 5 / 10 controls only the quick recent list. The local Library may retain older recordings. Off disables transcript history and clears the local index."
                ),
                systemImage: "lock.shield"
            )
            .font(SuperDictateDesign.TypeStyle.caption)
            .foregroundStyle(SuperDictateDesign.ColorRole.textSecondary)

            Divider()

            Button(role: .destructive) {
                confirmClearHistory = true
            } label: {
                Label(
                    text("Очистить историю…", "Clear History…"),
                    systemImage: "trash"
                )
            }
            .disabled(!snapshot.historyEnabled && snapshot.libraryRecordingCount == 0)
        }
    }

    private var systemSection: some View {
        SettingsGroup {
            SettingsValueRow(
                title: text("Фоновая служба", "Background service"),
                value: serviceLabel
            )

            ForEach(snapshot.permissions) { permission in
                HStack {
                    Label(
                        permissionTitle(permission.kind),
                        systemImage: permission.state == .granted
                            ? "checkmark.circle.fill"
                            : "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(
                        permission.state == .granted
                            ? SuperDictateDesign.ColorRole.textPrimary
                            : SuperDictateDesign.ColorRole.warning
                    )
                    Spacer()
                    if permission.state == .missing {
                        Button(text("Открыть", "Open")) {
                            onCommand(.openPermission(permission.kind))
                        }
                    } else {
                        Text(text("Разрешено", "Granted"))
                            .foregroundStyle(SuperDictateDesign.ColorRole.textSecondary)
                    }
                }
            }

            SettingsValueRow(
                title: text("Версия", "Version"),
                value: snapshot.appVersion
            )
            updateRow

            HStack {
                serviceButton
                Spacer()
                Button(copy.systemStatus) {
                    onCommand(.openSystemStatus)
                }
            }
        }
    }

    @ViewBuilder
    private var updateRow: some View {
        switch snapshot.updateState {
        case .checking:
            HStack {
                ProgressView().controlSize(.small)
                Text(text("Проверяю обновления…", "Checking for updates…"))
            }

        case .current(let version):
            SettingsValueRow(
                title: text("Обновления", "Updates"),
                value: text("Актуальная версия \(version)", "Up to date · \(version)")
            )

        case .available(let version):
            HStack {
                Text(text(
                    "Доступна версия \(version)",
                    "Version \(version) is available"
                ))
                Spacer()
                Button(text("Установить", "Install")) {
                    onCommand(.installAvailableUpdate)
                }
            }

        case .installing(let version, let phase):
            HStack(alignment: .firstTextBaseline) {
                ProgressView().controlSize(.small)
                VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.micro) {
                    Text(text(
                        "Установка версии \(version)",
                        "Installing version \(version)"
                    ))
                    if !phase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(phase)
                            .font(SuperDictateDesign.TypeStyle.caption)
                            .foregroundStyle(SuperDictateDesign.ColorRole.textSecondary)
                    }
                }
            }

        case .failed(let message):
            HStack(alignment: .top) {
                Text(message)
                    .foregroundStyle(SuperDictateDesign.ColorRole.warning)
                Spacer()
                Button(text("Повторить", "Retry")) {
                    onCommand(.checkForUpdates)
                }
            }
        }
    }

    @ViewBuilder
    private var serviceButton: some View {
        switch snapshot.serviceState {
        case .running:
            Button(text("Перезапустить службу", "Restart service")) {
                onCommand(.restartService)
            }
        case .starting:
            Button(text("Служба запускается…", "Service is starting…")) {}
                .disabled(true)
        case .stopped:
            Button(text("Запустить службу", "Start service")) {
                onCommand(.startService)
            }
        case .needsAttention:
            Button(text("Перезапустить службу", "Restart service")) {
                onCommand(.restartService)
            }
        }
    }

    private var serviceLabel: String {
        switch snapshot.serviceState {
        case .running: return text("Работает", "Running")
        case .starting: return text("Запускается", "Starting")
        case .stopped: return text("Остановлена", "Stopped")
        case .needsAttention: return text("Требует внимания", "Needs attention")
        }
    }

    private func recentModeTitle(_ mode: SuperDictateRecentTranscriptMode) -> String {
        switch mode {
        case .off: return text("Не сохранять", "Off")
        case .last1: return text("Последняя 1", "Last 1")
        case .last5: return text("Последние 5", "Last 5")
        case .last10: return text("Последние 10", "Last 10")
        }
    }

    private func sectionTitle(_ section: SuperDictateSettingsSection) -> String {
        switch section {
        case .dictation: return text("Диктовка", "Dictation")
        case .models: return text("Модели", "Models")
        case .privacy: return text("Приватность", "Privacy")
        case .system: return text("Система", "System")
        }
    }

    private func sectionSymbol(_ section: SuperDictateSettingsSection) -> String {
        switch section {
        case .dictation: return "waveform"
        case .models: return "cpu"
        case .privacy: return "lock.shield"
        case .system: return "gearshape.2"
        }
    }

    private func permissionTitle(_ permission: SuperDictatePermissionKind) -> String {
        switch permission {
        case .microphone: return text("Микрофон", "Microphone")
        case .accessibility: return text("Универсальный доступ", "Accessibility")
        case .inputMonitoring: return text("Мониторинг ввода", "Input Monitoring")
        }
    }

    private func text(_ russian: String, _ english: String) -> String {
        copy.text(russian, english)
    }
}

private struct SettingsGroup<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SuperDictateDesign.Spacing.component) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SettingsValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(SuperDictateDesign.ColorRole.textPrimary)
            Spacer(minLength: SuperDictateDesign.Spacing.section)
            Text(value)
                .foregroundStyle(SuperDictateDesign.ColorRole.textSecondary)
                .multilineTextAlignment(.trailing)
        }
    }
}
