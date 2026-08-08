import SwiftUI

/// Native semantic design tokens for SuperDictate.
///
/// The machine-readable source of truth lives in `design/superdictate.tokens.json`.
/// Apple UI deliberately resolves color and typography through system APIs instead
/// of copying literal web palette values. This preserves macOS accent color,
/// Dark Mode, Increased Contrast and future platform material behavior.
public enum SuperDictateDesign {
    public enum Spacing {
        public static let micro: CGFloat = 4
        public static let inline: CGFloat = 8
        public static let compact: CGFloat = 12
        public static let component: CGFloat = 16
        public static let comfortable: CGFloat = 20
        public static let contentGutter: CGFloat = 24
        public static let section: CGFloat = 32
        public static let major: CGFloat = 40
    }

    public enum Radius {
        public static let compact: CGFloat = 6
        public static let surface: CGFloat = 10
        public static let floating: CGFloat = 14
    }

    public enum Motion {
        public static let fast: Double = 0.12
        public static let standard: Double = 0.18
        public static let deliberate: Double = 0.24
        public static let hudEnter: Double = 0.28
    }

    public enum TypeStyle {
        /// Rare large empty-state/title treatment.
        public static let display: Font = .system(size: 28, weight: .semibold)
        public static let title: Font = .system(size: 20, weight: .semibold)
        public static let heading: Font = .system(size: 16, weight: .semibold)
        public static let body: Font = .system(size: 15, weight: .regular)
        public static let interface: Font = .system(size: 13, weight: .regular)
        public static let interfaceMedium: Font = .system(size: 13, weight: .medium)
        public static let caption: Font = .system(size: 12, weight: .regular)
        public static let captionMedium: Font = .system(size: 12, weight: .medium)
        public static let timestamp: Font = .system(size: 12, weight: .regular, design: .monospaced)
    }

    public enum ColorRole {
        /// Primary content label. Resolves with the OS instead of a fixed RGB value.
        public static let textPrimary: Color = .primary
        public static let textSecondary: Color = .secondary
        public static let textTertiary: Color = Color(nsColor: .tertiaryLabelColor)

        public static let canvas: Color = Color(nsColor: .windowBackgroundColor)
        public static let surfaceSecondary: Color = Color(nsColor: .controlBackgroundColor)
        public static let surfaceTertiary: Color = Color(nsColor: .underPageBackgroundColor)

        public static let borderSubtle: Color = Color(nsColor: .separatorColor).opacity(0.58)
        public static let borderDefault: Color = Color(nsColor: .separatorColor)

        /// Generic interactive emphasis follows the user's macOS accent color.
        public static let actionPrimary: Color = .accentColor
        public static let recording: Color = .red
        public static let success: Color = .green
        public static let warning: Color = .orange
        public static let destructive: Color = .red
    }

    public enum Layout {
        public static let documentMaxReadableWidth: CGFloat = 760
        public static let sidebarIdealWidth: CGFloat = 212
        public static let sidebarMinWidth: CGFloat = 176
        public static let sidebarMaxWidth: CGFloat = 280
    }
}

public extension View {
    /// Keeps document-style content readable on large Mac windows while still
    /// allowing the surrounding split view to grow naturally.
    func superDictateReadableDocument() -> some View {
        frame(maxWidth: SuperDictateDesign.Layout.documentMaxReadableWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
