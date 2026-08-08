import Foundation

/// Atomic manifest mutations owned by the package-store actor.
///
/// Audio adapters must not perform `load → mutate → save` themselves. Keeping
/// these operations actor-isolated prevents microphone and system-audio writers
/// from racing and losing each other's finalized chunk descriptors.
public extension JSONSuperDictateMemoryPackageStore {
    @discardableResult
    func appendFinalizedChunk(
        recordingID: UUID,
        chunk: SuperDictateMemoryAudioChunk
    ) throws -> SuperDictateMemoryRecordingManifest {
        guard var manifest = try loadManifest(recordingID: recordingID) else {
            throw SuperDictateMemoryPackageStoreError.packageMissing(recordingID)
        }
        try manifest.appendFinalizedChunk(chunk)
        try saveManifest(manifest)
        return manifest
    }

    @discardableResult
    func beginFinalization(
        recordingID: UUID
    ) throws -> SuperDictateMemoryRecordingManifest {
        guard var manifest = try loadManifest(recordingID: recordingID) else {
            throw SuperDictateMemoryPackageStoreError.packageMissing(recordingID)
        }
        try manifest.beginFinalization()
        try saveManifest(manifest)
        return manifest
    }

    @discardableResult
    func markReady(
        recordingID: UUID
    ) throws -> SuperDictateMemoryRecordingManifest {
        guard var manifest = try loadManifest(recordingID: recordingID) else {
            throw SuperDictateMemoryPackageStoreError.packageMissing(recordingID)
        }
        try manifest.markReady()
        try saveManifest(manifest)
        return manifest
    }

    @discardableResult
    func markNeedsAttention(
        recordingID: UUID,
        message: String
    ) throws -> SuperDictateMemoryRecordingManifest {
        guard var manifest = try loadManifest(recordingID: recordingID) else {
            throw SuperDictateMemoryPackageStoreError.packageMissing(recordingID)
        }
        try manifest.markNeedsAttention(message)
        try saveManifest(manifest)
        return manifest
    }
}
