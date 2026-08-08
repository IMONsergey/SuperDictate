import Foundation
import XCTest
@testable import SuperDictateCore

extension ProductStateTests {
    private func sourceV2Chunk(
        source: SuperDictateMemoryAudioSource,
        sequence: Int,
        id: UUID = UUID(),
        start: Int64 = 0,
        end: Int64 = 1_000
    ) throws -> SuperDictateMemoryAudioChunk {
        try SuperDictateMemoryAudioChunk(
            id: id,
            source: source,
            sequence: sequence,
            relativePath: SuperDictateMemoryAudioChunk.canonicalRelativePath(
                source: source,
                sequence: sequence,
                chunkID: id
            ),
            sessionStartMilliseconds: start,
            sessionEndMilliseconds: end,
            sampleRate: 48_000,
            channelCount: source == .system ? 2 : 1,
            byteLength: 4_096,
            sha256: String(repeating: "a", count: 64)
        )
    }

    func testDualTrackSequencesAreIndependentCanonicalAndDescribeDuration() throws {
        let microphone = try sourceV2Chunk(
            source: .microphone,
            sequence: 0,
            start: 100,
            end: 1_100
        )
        let system = try sourceV2Chunk(
            source: .system,
            sequence: 0,
            start: 250,
            end: 1_500
        )
        let manifest = try SuperDictateMemoryRecordingManifest(
            recordingID: UUID(),
            createdAt: Date(),
            chunks: [system, microphone]
        )
        XCTAssertEqual(manifest.chunks(for: .microphone), [microphone])
        XCTAssertEqual(manifest.chunks(for: .system), [system])
        XCTAssertTrue(microphone.relativePath.hasPrefix("audio/microphone/000000__"))
        XCTAssertTrue(system.relativePath.hasPrefix("audio/system/000000__"))
        XCTAssertEqual(manifest.durationMilliseconds, 1_500)
        XCTAssertEqual(manifest.sources, Set([.microphone, .system]))
    }

    func testSameSourceDuplicateSequenceIsRejected() throws {
        let first = try sourceV2Chunk(source: .microphone, sequence: 2)
        let second = try sourceV2Chunk(source: .microphone, sequence: 2)
        XCTAssertThrowsError(
            try SuperDictateMemoryRecordingManifest(
                recordingID: UUID(),
                createdAt: Date(),
                chunks: [first, second]
            )
        ) { error in
            XCTAssertEqual(
                error as? SuperDictateMemoryManifestError,
                .duplicateSequence(source: .microphone, sequence: 2)
            )
        }
    }

    func testChunkPathMustMatchSourceSequenceAndChunkIdentity() {
        let id = UUID()
        let wrong = SuperDictateMemoryAudioChunk.canonicalRelativePath(
            source: .system,
            sequence: 1,
            chunkID: id
        )
        XCTAssertThrowsError(
            try SuperDictateMemoryAudioChunk(
                id: id,
                source: .system,
                sequence: 2,
                relativePath: wrong,
                sessionStartMilliseconds: 0,
                sessionEndMilliseconds: 100,
                sampleRate: 48_000,
                channelCount: 2,
                byteLength: 100,
                sha256: String(repeating: "a", count: 64)
            )
        ) { error in
            XCTAssertEqual(
                error as? SuperDictateMemoryManifestError,
                .invalidChunkPath(wrong)
            )
        }
    }

    func testDecodedChunkCannotBypassCanonicalPathValidation() throws {
        let chunk = try sourceV2Chunk(source: .system, sequence: 0)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(chunk)) as? [String: Any]
        )
        object["relativePath"] = "../../escape.caf"
        let tampered = try JSONSerialization.data(withJSONObject: object)
        XCTAssertThrowsError(
            try JSONDecoder().decode(SuperDictateMemoryAudioChunk.self, from: tampered)
        ) { error in
            XCTAssertEqual(
                error as? SuperDictateMemoryManifestError,
                .invalidChunkPath("../../escape.caf")
            )
        }
    }

    func testReadyRequiresAtLeastOneFinalizedSourceChunk() throws {
        var empty = try SuperDictateMemoryRecordingManifest(
            recordingID: UUID(),
            createdAt: Date()
        )
        try empty.beginFinalization()
        XCTAssertThrowsError(try empty.markReady()) { error in
            XCTAssertEqual(
                error as? SuperDictateMemoryManifestError,
                .readyWithoutSourceAudio
            )
        }
        XCTAssertEqual(empty.state, .finalizing)
    }

    func testReadyLifecycleIsTerminalForOrdinaryWrites() throws {
        let source = try sourceV2Chunk(source: .microphone, sequence: 0)
        var manifest = try SuperDictateMemoryRecordingManifest(
            recordingID: UUID(),
            createdAt: Date(),
            chunks: [source]
        )
        try manifest.beginFinalization()
        try manifest.markReady()
        XCTAssertEqual(manifest.state, .ready)
        XCTAssertThrowsError(
            try manifest.appendFinalizedChunk(
                try sourceV2Chunk(source: .microphone, sequence: 1)
            )
        ) { error in
            XCTAssertEqual(
                error as? SuperDictateMemoryManifestError,
                .chunkAppendNotAllowed(.ready)
            )
        }
        XCTAssertThrowsError(try manifest.markNeedsAttention("ordinary warning")) { error in
            XCTAssertEqual(
                error as? SuperDictateMemoryManifestError,
                .invalidStateTransition(from: .ready, to: .needsAttention)
            )
        }
    }

    func testIntegrityLayerCanDowngradeReadySource() throws {
        let source = try sourceV2Chunk(source: .microphone, sequence: 0)
        var manifest = try SuperDictateMemoryRecordingManifest(
            recordingID: UUID(),
            createdAt: Date(),
            chunks: [source]
        )
        try manifest.beginFinalization()
        try manifest.markReady()
        try manifest.markIntegrityNeedsAttention("checksum mismatch")
        XCTAssertEqual(manifest.state, .needsAttention)
        XCTAssertEqual(manifest.issue, "checksum mismatch")
    }
}
