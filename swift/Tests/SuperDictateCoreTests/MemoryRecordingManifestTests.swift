import Foundation
import XCTest
@testable import SuperDictateCore

extension ProductStateTests {
    private func memoryChunk(
        source: SuperDictateMemoryAudioSource,
        sequence: Int,
        id: UUID = UUID(),
        start: Int64 = 0,
        end: Int64 = 1_000,
        path: String? = nil
    ) throws -> SuperDictateMemoryAudioChunk {
        try SuperDictateMemoryAudioChunk(
            id: id,
            source: source,
            sequence: sequence,
            relativePath: path ?? "\(source.rawValue)/\(sequence).caf",
            sessionStartMilliseconds: start,
            sessionEndMilliseconds: end,
            sampleRate: 48_000,
            channelCount: 1,
            byteLength: 4_096,
            sha256: String(repeating: "a", count: 64)
        )
    }

    func testMemoryManifestKeepsSourceSequencesIndependent() throws {
        let microphone = try memoryChunk(source: .microphone, sequence: 0)
        let system = try memoryChunk(source: .system, sequence: 0)
        let manifest = try SuperDictateMemoryRecordingManifest(
            recordingID: UUID(),
            createdAt: Date(),
            chunks: [system, microphone]
        )

        XCTAssertEqual(manifest.chunks(for: .microphone), [microphone])
        XCTAssertEqual(manifest.chunks(for: .system), [system])
    }

    func testMemoryManifestRejectsDuplicateSequenceWithinOneSource() throws {
        let first = try memoryChunk(source: .microphone, sequence: 1)
        let second = try memoryChunk(source: .microphone, sequence: 1)

        XCTAssertThrowsError(
            try SuperDictateMemoryRecordingManifest(
                recordingID: UUID(),
                createdAt: Date(),
                chunks: [first, second]
            )
        ) { error in
            XCTAssertEqual(
                error as? SuperDictateMemoryManifestError,
                .duplicateSequence(source: .microphone, sequence: 1)
            )
        }
    }

    func testMemoryManifestRejectsTraversalAndInvalidChecksum() {
        XCTAssertThrowsError(
            try SuperDictateMemoryAudioChunk(
                source: .system,
                sequence: 0,
                relativePath: "../outside.caf",
                sessionStartMilliseconds: 0,
                sessionEndMilliseconds: 1,
                sampleRate: 48_000,
                channelCount: 2,
                byteLength: 100,
                sha256: String(repeating: "a", count: 64)
            )
        ) { error in
            XCTAssertEqual(
                error as? SuperDictateMemoryManifestError,
                .invalidChunkPath("../outside.caf")
            )
        }

        XCTAssertThrowsError(
            try SuperDictateMemoryAudioChunk(
                source: .system,
                sequence: 0,
                relativePath: "system/0.caf",
                sessionStartMilliseconds: 0,
                sessionEndMilliseconds: 1,
                sampleRate: 48_000,
                channelCount: 2,
                byteLength: 100,
                sha256: "not-a-sha"
            )
        )
    }

    func testDecodedChunkCannotBypassPathValidation() throws {
        let source = try memoryChunk(source: .system, sequence: 0)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(source)) as? [String: Any]
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

    func testDecodedManifestCannotBypassDuplicateSequenceValidation() throws {
        let first = try memoryChunk(source: .microphone, sequence: 0)
        let second = try memoryChunk(source: .microphone, sequence: 0)
        let validShell = try SuperDictateMemoryRecordingManifest(
            recordingID: UUID(),
            createdAt: Date(timeIntervalSince1970: 10),
            chunks: []
        )
        var shellObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(validShell)) as? [String: Any]
        )
        shellObject["chunks"] = [
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(first)),
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(second)),
        ]
        let tampered = try JSONSerialization.data(withJSONObject: shellObject)

        XCTAssertThrowsError(
            try JSONDecoder().decode(SuperDictateMemoryRecordingManifest.self, from: tampered)
        ) { error in
            XCTAssertEqual(
                error as? SuperDictateMemoryManifestError,
                .duplicateSequence(source: .microphone, sequence: 0)
            )
        }
    }

    func testFailedAppendLeavesManifestUnchanged() throws {
        let original = try memoryChunk(source: .system, sequence: 0)
        let duplicate = try memoryChunk(source: .system, sequence: 0)
        var manifest = try SuperDictateMemoryRecordingManifest(
            recordingID: UUID(),
            createdAt: Date(),
            chunks: [original]
        )

        XCTAssertThrowsError(try manifest.appendFinalizedChunk(duplicate))
        XCTAssertEqual(manifest.chunks, [original])
    }

    func testManifestRoundTripPreservesDualTrackDescriptors() throws {
        let manifest = try SuperDictateMemoryRecordingManifest(
            recordingID: UUID(),
            createdAt: Date(timeIntervalSince1970: 100),
            state: .ready,
            chunks: [
                try memoryChunk(source: .microphone, sequence: 0, start: 0, end: 2_000),
                try memoryChunk(source: .system, sequence: 0, start: 120, end: 2_120),
            ]
        )

        let decoded = try JSONDecoder().decode(
            SuperDictateMemoryRecordingManifest.self,
            from: JSONEncoder().encode(manifest)
        )
        XCTAssertEqual(decoded, manifest)
        XCTAssertNoThrow(try decoded.validate())
    }
}
