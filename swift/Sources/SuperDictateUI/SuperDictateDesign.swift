import AppKit
import SwiftUI

/// Native design roles for the macOS product surface.
///
/// Values intentionally resolve through macOS semantic APIs so the interface
/// follows accent color, Dark Mode and Increased Contrast instead of baking a
/// web palette into SwiftUI.
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

    public enum TypeStyle {
        public static let display: Font = .system(size: 28, weight: .semibold)
        public static let title: Font = .system(size: 20, weight: .semibold)
        public static let heading: Font = .system(size: 16, weight: .semibold)
        public static let body: Font = .system(size: 15)
        public static let interface: Font = .system(size: 13)
        public static let interfaceMedium: Font = .system(size: 13, weight: .medium)
        public static let caption: Font = .system(size: 12)
        public static let timestamp: Font = .system(size: 12, design: .monospaced)
    }

    public enum ColorRole {
        public static let textPrimary: Color = .primary
        public static let textSecondary: Color = .secondary
        public static let textTertiary = Color(nsColor: .tertiaryLabelColor)
        public static let canvas = Color(nsColor: .windowBackgroundColor)
        public static let surfaceSecondary = Color(nsColor: .controlBackgroundColor)
        public static let surfaceTertiary = Color(nsColor: .underPageBackgroundColor)
        public static let borderSubtle = Color(nsColor: .separatorColor).opacity(0.58)
        public static let actionPrimary: Color = .accentColor
        public static let recording: Color = .red
        public static let success: Color = .green
        public static let warning: Color = .orange
        public static let destructive: Color = .red
    }

    public enum Layout {
        public static let sidebarIdealWidth: CGFloat = 212
        public static let sidebarMinWidth: CGFloat = 176
        public static let sidebarMaxWidth: CGFloat = 280
        public static let documentMaxReadableWidth: CGFloat = 760
    }
}

public extension View {
    func superDictateReadableDocument() -> some View {
        frame(maxWidth: SuperDictateDesign.Layout.documentMaxReadableWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
