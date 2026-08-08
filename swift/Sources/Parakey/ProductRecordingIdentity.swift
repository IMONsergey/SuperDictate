import Foundation

/// Identity allocated exactly once for a real in-session audio capture.
///
/// The runtime creates this only after audio capture successfully starts, then
/// carries it through ASR, history, the live product projection and the durable
/// Library. Transcript text therefore never becomes the identity of a new row.
struct ProductRecordingIdentity: Equatable, Sendable {
    let id: UUID
    let createdAt: Date

    static func now() -> ProductRecordingIdentity {
        ProductRecordingIdentity(id: UUID(), createdAt: Date())
    }
}
