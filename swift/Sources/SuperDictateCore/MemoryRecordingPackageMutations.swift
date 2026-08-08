import Foundation

/// Actor-isolated manifest mutations. External capture adapters must never do
/// their own load-modify-save cycle: microphone and system tracks can finalize
/// concurrently, and the store actor is the one place that serializes updates.
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

/// Core-only integrity mutation. Recovery may downgrade a previously-ready
/// package only when physical source verification proves it unhealthy.
extension JSONSuperDictateMemoryPackageStore {
    @discardableResult
    func markIntegrityNeedsAttention(
        recordingID: UUID,
        message: String
    ) throws -> SuperDictateMemoryRecordingManifest {
        guard var manifest = try loadManifest(recordingID: recordingID) else {
            throw SuperDictateMemoryPackageStoreError.packageMissing(recordingID)
        }
        try manifest.markIntegrityNeedsAttention(message)
        try saveManifest(manifest)
        return manifest
    }
}
