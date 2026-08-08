import Foundation

public enum SuperDictateBuiltInSummaryTemplate: String, Codable, CaseIterable, Sendable {
    case auto
    case meeting
    case interview
    case discovery
    case journal
}

public struct SuperDictateSummaryTemplateSection: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var instruction: String

    public init(
        id: UUID = UUID(),
        title: String,
        instruction: String
    ) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.instruction = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public enum SuperDictateSummaryTemplateError: Error, Equatable, Sendable {
    case emptyName
    case emptySection
    case tooManySections(Int)
    case instructionTooLong(Int)
}

/// Product-level summary lens.
///
/// Built-in lenses use stable semantic IDs; UI localizes their names. Custom
/// templates own a user-visible name and explicit section instructions. Providers
/// consume this contract but never decide how templates are stored/presented.
public struct SuperDictateSummaryTemplate: Identifiable, Codable, Equatable, Sendable {
    public static let maximumSections = 12
    public static let maximumInstructionCharacters = 4_000

    public var id: UUID
    public var builtIn: SuperDictateBuiltInSummaryTemplate?
    public var customName: String?
    public var sections: [SuperDictateSummaryTemplateSection]
    public var extractsTasks: Bool

    public init(
        id: UUID = UUID(),
        builtIn: SuperDictateBuiltInSummaryTemplate,
        sections: [SuperDictateSummaryTemplateSection] = [],
        extractsTasks: Bool = true
    ) throws {
        try Self.validate(sections)
        self.id = id
        self.builtIn = builtIn
        self.customName = nil
        self.sections = sections
        self.extractsTasks = extractsTasks
    }

    public init(
        id: UUID = UUID(),
        customName: String,
        sections: [SuperDictateSummaryTemplateSection],
        extractsTasks: Bool = true
    ) throws {
        let name = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw SuperDictateSummaryTemplateError.emptyName }
        try Self.validate(sections)
        self.id = id
        self.builtIn = nil
        self.customName = name
        self.sections = sections
        self.extractsTasks = extractsTasks
    }

    public var isBuiltIn: Bool { builtIn != nil }

    private static func validate(_ sections: [SuperDictateSummaryTemplateSection]) throws {
        guard sections.count <= maximumSections else {
            throw SuperDictateSummaryTemplateError.tooManySections(sections.count)
        }
        for section in sections {
            guard !section.title.isEmpty, !section.instruction.isEmpty else {
                throw SuperDictateSummaryTemplateError.emptySection
            }
            guard section.instruction.count <= maximumInstructionCharacters else {
                throw SuperDictateSummaryTemplateError.instructionTooLong(section.instruction.count)
            }
        }
    }
}

public enum SuperDictateBuiltInSummaryTemplates {
    public static func template(
        _ kind: SuperDictateBuiltInSummaryTemplate
    ) -> SuperDictateSummaryTemplate {
        // Static built-ins are compile-time controlled; forced construction here
        // is safe because every section below satisfies the validated contract.
        switch kind {
        case .auto:
            return try! SuperDictateSummaryTemplate(
                builtIn: .auto,
                sections: [],
                extractsTasks: true
            )

        case .meeting:
            return try! SuperDictateSummaryTemplate(
                builtIn: .meeting,
                sections: [
                    .init(title: "Overview", instruction: "Summarize the purpose and outcome concisely."),
                    .init(title: "Decisions", instruction: "List decisions that are explicitly supported by evidence."),
                    .init(title: "Open questions", instruction: "List unresolved questions or dependencies supported by evidence."),
                ],
                extractsTasks: true
            )

        case .interview:
            return try! SuperDictateSummaryTemplate(
                builtIn: .interview,
                sections: [
                    .init(title: "Profile", instruction: "Summarize the interviewee context without inventing facts."),
                    .init(title: "Key points", instruction: "Capture the strongest claims, experiences and examples."),
                    .init(title: "Quotes to revisit", instruction: "Surface evidence-backed passages worth revisiting; paraphrase unless verbatim output is explicitly requested."),
                ],
                extractsTasks: false
            )

        case .discovery:
            return try! SuperDictateSummaryTemplate(
                builtIn: .discovery,
                sections: [
                    .init(title: "Context", instruction: "Summarize the current situation and goal."),
                    .init(title: "Needs", instruction: "List explicit needs, constraints and success criteria."),
                    .init(title: "Risks", instruction: "Capture stated risks, blockers and unknowns."),
                    .init(title: "Next steps", instruction: "Summarize agreed next steps; task extraction handles actionable items separately."),
                ],
                extractsTasks: true
            )

        case .journal:
            return try! SuperDictateSummaryTemplate(
                builtIn: .journal,
                sections: [
                    .init(title: "Reflection", instruction: "Summarize the reflection in the speaker's intent without adding advice."),
                    .init(title: "Themes", instruction: "Capture recurring themes or tensions grounded in the recording."),
                ],
                extractsTasks: false
            )
        }
    }
}
