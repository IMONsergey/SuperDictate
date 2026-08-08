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

/// Integrity-only package mutations. They remain internal to SuperDictateCore so
/// ordinary capture adapters cannot bypass the public recording lifecycle.
extension JSONSuperDictateMemoryPackageStore {
    /// Reattach a source descriptor only after recovery independently verified
    /// the immutable source bytes against durable journal evidence. Unlike the
    /// public append path, this intentionally preserves a `.ready` manifest: a
    /// crash may have lost the manifest mutation after the audio itself became
    /// durable, but that does not reopen the recording for ordinary writes.
    @discardableResult
    func reattachVerifiedChunk(
        recordingID: UUID,
        chunk: SuperDictateMemoryAudioChunk
    ) throws -> SuperDictateMemoryRecordingManifest {
        guard var manifest = try loadManifest(recordingID: recordingID) else {
            throw SuperDictateMemoryPackageStoreError.packageMissing(recordingID)
        }

        manifest.chunks.append(chunk)
        do {
            try manifest.validate()
        } catch {
            manifest.chunks.removeLast()
            throw error
        }

        try saveManifest(manifest)
        return manifest
    }

    /// Recovery may downgrade a previously-ready package only when physical
    /// source verification proves it unhealthy.
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
