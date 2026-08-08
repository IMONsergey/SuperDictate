import SwiftUI

/// Module-local overload used by the product UI whenever source chronology can
/// legitimately be unknown (for example legacy transcript history).
///
/// Do not coalesce an unknown source date to `Date()`: doing so turns missing
/// metadata into false product truth. Known dates keep the caller's native
/// `Date.FormatStyle`; unknown dates render a quiet explicit label instead.
extension Text {
    init(_ date: Date?, format: Date.FormatStyle) {
        if let date {
            self = Text(date, format: format)
        } else {
            self = Text("Date unavailable")
        }
    }
}
