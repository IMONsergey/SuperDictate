import Foundation

/// Recovery inventory is intentionally broader than `existingRecordingIDs()`.
///
/// The normal product listing returns only validated package directories. An
/// integrity scan must also see UUID-named entries whose type is unsafe (for
/// example, a symlink replacing a recording package), so the scanner can report
/// that recording ID as failed instead of silently making it disappear.
extension JSONSuperDictateMemoryPackageStore {
    func recoveryCandidateRecordingIDs() throws -> [UUID] {
        let probeID = UUID()
        let recordingsDirectory = packageURL(recordingID: probeID)
            .deletingLastPathComponent()
        let names = try FileManager.default.contentsOfDirectory(
            atPath: recordingsDirectory.path
        )
        return Set(names.compactMap(UUID.init(uuidString:)))
            .sorted { $0.uuidString < $1.uuidString }
    }
}
