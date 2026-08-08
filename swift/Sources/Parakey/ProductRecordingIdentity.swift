import Foundation

/// Identity allocated once a real audio recording successfully starts.
/// It is carried through ASR/history/Library so transcript text never becomes
/// the primary identity of new recordings.
struct ProductRecordingIdentity: Equatable, Sendable {
    let id: UUID
    let createdAt: Date

    static func now() -> ProductRecordingIdentity {
        ProductRecordingIdentity(id: UUID(), createdAt: Date())
    }
}
