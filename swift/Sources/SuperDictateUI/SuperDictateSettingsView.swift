import SwiftUI
import SuperDictateCore

/// Native Settings v2 surface.
///
/// This view is a projection over the existing runtime settings/service model;
/// it does not persist anything itself. Every mutation is emitted as a typed
/// command so the current tested runtime handlers remain authoritative during
/// migration away from the legacy control panel.
public struct SuperDictateSettingsView: View {
    private let snapshot: SuperDictateSettingsSnapshot
    private let language: SuperDictateInterfaceLanguage
    private let onCommand: (SuperDictateSettingsCommand) -> Void

    @State private var section: SuperDictateSettingsSection = .dictation

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
    }

    private var copy: SuperDictateCopy {
        SuperDictateCopy(language: language)
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch section {
        case .dictation:
            dictationSection
        case .models:
            modelsSection
        case .privacy:
            privacySection
        case .system:
            systemSection
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
                .foregroundStyle(snapshot.speechModelReady
                                 ? SuperDictateDesign.ColorRole.success
                                 : SuperDictateDesign.ColorRole.textSecondary)
            }

            Text(text(
                "Модель речи — системная настройка. Она не занимает место в основном интерфейсе и меняется только здесь.",
                "Speech model choice is a system setting. It stays out of the primary interface and is managed here."
            ))
            .font(SuperDictateDesign.TypeStyle.caption)
            .foregroundStyle(SuperDictateDesign.ColorRole.textSecondary)

            Button(text("Управление моделями…", "Manage models…")) {
                onCommand(.openModelManager)
            }
        }
    }

    private var privacySection: some View {
        SettingsGroup {
            Toggle(
                text("Сохранять историю диктовок", "Keep dictation history"),
                isOn: Binding(
                    get: { snapshot.historyEnabled },
                    set: { onCommand(.setHistoryEnabled($0)) }
                )
            )
            SettingsValueRow(
                title: text("Лимит истории", "History limit"),
                value: snapshot.historyLimitDescription
            )
            SettingsValueRow(
                title: text("Записей в библиотеке", "Library recordings"),
                value: String(snapshot.libraryRecordingCount)
            )

            Label(
                text(
                    "Библиотека и поиск работают локально. Отключение истории должно скрыть и очистить локальный индекс.",
                    "Library and search are local. Turning history off must hide and clear the local index."
                ),
                systemImage: "lock.shield"
            )
            .font(SuperDictateDesign.TypeStyle.caption)
            .foregroundStyle(SuperDictateDesign.ColorRole.textSecondary)
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
                    .foregroundStyle(permission.state == .granted
                                     ? SuperDictateDesign.ColorRole.textPrimary
                                     : SuperDictateDesign.ColorRole.warning)
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

            HStack {
                Text(text("Версия", "Version"))
                Spacer()
                Text(snapshot.appVersion)
                    .foregroundStyle(SuperDictateDesign.ColorRole.textSecondary)
            }

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
                Text(text("Доступна версия \(version)", "Version \(version) is available"))
                Spacer()
                Button(text("Установить", "Install")) {
                    onCommand(.installAvailableUpdate)
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
