import Foundation

public enum SuperDictateInterfaceLanguage: String, Codable, CaseIterable, Sendable {
    case russian = "ru"
    case english = "en"
}

struct SuperDictateCopy: Sendable {
    let language: SuperDictateInterfaceLanguage

    func text(_ russian: String, _ english: String) -> String {
        language == .russian ? russian : english
    }

    var today: String { text("Сегодня", "Today") }
    var library: String { text("Библиотека", "Library") }
    var tasks: String { text("Задачи", "Tasks") }
    var ask: String { "Ask" }
    var settings: String { text("Настройки", "Settings") }
    var systemStatus: String { text("Состояние системы", "System Status") }
    var more: String { text("Ещё", "More") }
    var record: String { text("Записать", "Record") }
    var stop: String { text("Стоп", "Stop") }
    var back: String { text("Назад", "Back") }
    var view: String { text("Вид", "View") }
    var summary: String { text("Выжимка", "Summary") }
    var transcript: String { text("Транскрипт", "Transcript") }
    var copyTranscript: String { text("Скопировать транскрипт", "Copy transcript") }
    var needsAttention: String { text("SuperDictate требует внимания", "SuperDictate needs attention") }
    var openSystemStatus: String {
        text("Открыть разрешения, службу и обновления", "Open permissions, service, and updates")
    }
    var stopRecordingHelp: String { text("Остановить запись", "Stop recording") }
    var startRecordingHelp: String { text("Начать запись", "Start recording") }
    var startingService: String { text("Подготавливаю службу диктовки…", "Preparing dictation service…") }
    var recordingLocally: String { text("Идёт локальная запись.", "Recording locally.") }
    var transcribingLatest: String { text("Превращаю последнюю запись в текст.", "Turning your latest recording into text.") }
    var attentionSubtitle: String { text("Есть действие, которое требует внимания.", "One item needs your attention.") }
    var todayDefaultSubtitle: String {
        text("Начните запись или продолжите с того места, где остановились.",
             "Record something or continue where you left off.")
    }
    var sectionNeedsAttention: String { text("Требует внимания", "Needs attention") }
    var sectionRecent: String { text("Недавние", "Recent") }
    var noAttention: String { text("Сейчас ничего не требует внимания.", "Nothing needs your attention.") }
    var startRecording: String { text("Начать запись", "Start recording") }
    var noRecordings: String { text("Записей пока нет", "No recordings yet") }
    var noRecordingsDetail: String {
        text("Здесь появятся ваши диктовки и сохранённые разговоры.",
             "Your dictations and captured conversations will appear here.")
    }
    var noTasks: String { text("Задач пока нет", "No tasks") }
    var noTasksDetail: String {
        text("Здесь появятся подтверждённые действия из записей.",
             "Verified actions from recordings will appear here.")
    }
    var askUnavailable: String { text("Ask пока не подключён", "Ask is not connected yet") }
    var askUnavailableDetail: String {
        text("Мы включим Ask только вместе с реальным поиском по источникам и ссылками на доказательства. Фейкового чат-интерфейса не будет.",
             "Ask will ship only with evidence-backed answers and source citations. No fake chat UI in the meantime.")
    }
    var noSummary: String { text("Выжимки пока нет.", "No summary yet.") }
    var noTranscript: String { text("Транскрипта пока нет.", "No transcript yet.") }
    var noVerifiedTasks: String {
        text("В этой записи пока нет подтверждённых задач.",
             "No verified tasks from this recording.")
    }
    var recording: String { text("Запись", "Recording") }
    var recordingAccessibility: String { text("Идёт запись", "Recording in progress") }
    var processingLatest: String { text("Расшифровываю последнюю запись…", "Transcribing latest recording…") }
    var dateUnavailable: String { text("Дата недоступна", "Date unavailable") }
}
