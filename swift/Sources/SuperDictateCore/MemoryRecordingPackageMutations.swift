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

/// Internal integrity-only mutation used by Core recovery. Unlike the public
/// operational attention transition, this may downgrade a previously-ready
/// package when the physical source bytes are later found missing/corrupt.
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
