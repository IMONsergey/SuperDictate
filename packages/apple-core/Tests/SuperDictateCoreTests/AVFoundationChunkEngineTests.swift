#if canImport(AVFoundation)
import AVFoundation
import Foundation
import XCTest
@testable import SuperDictateCore

final class AVFoundationChunkEngineTests: XCTestCase {
    func testCAFEncoderProducesContainerBytesDurationAndLevel() throws {
        let sampleRate = 16_000.0
        let frameCount = AVAudioFrameCount(1_600)
        let format = try XCTUnwrap(
            AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: sampleRate,
                channels: 1,
                interleaved: false
            )
        )
        let buffer = try XCTUnwrap(
            AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
        )
        buffer.frameLength = frameCount
        let samples = try XCTUnwrap(buffer.floatChannelData?[0])
        for index in 0..<Int(frameCount) {
            samples[index] = Float(sin(Double(index) / 12.0)) * 0.25
        }

        let chunk = try AVFoundationPCMChunkEncoder.encodeCAF(buffers: [buffer])

        XCTAssertEqual(String(data: Data(chunk.data.prefix(4)), encoding: .ascii), "caff")
        XCTAssertEqual(chunk.frameCount, Int64(frameCount))
        XCTAssertEqual(chunk.durationMilliseconds, 100)
        XCTAssertEqual(chunk.format.sampleRate, sampleRate)
        XCTAssertEqual(chunk.format.channelCount, 1)
        XCTAssertGreaterThan(chunk.rmsLevel, 0.05)
        XCTAssertLessThanOrEqual(chunk.rmsLevel, 1)
    }

    func testEncodedChunkRecorderPersistsChunksInSequence() async throws {
        let writer = RecordingChunkWriterSpy()
        let recordingID = UUID(uuidString: "00000000-0000-0000-0000-000000010001")!
        let assetID = UUID(uuidString: "00000000-0000-0000-0000-000000020001")!
        let recorder = AppleEncodedChunkRecorder(
            writer: writer,
            recordingID: recordingID,
            assetID: assetID
        )
        let format = AppleAudioFormatDescription(
            sampleRate: 16_000,
            channelCount: 1,
            commonFormat: "pcmFormatFloat32",
            interleaved: false
        )
        let firstChunk = AppleEncodedAudioChunk(
            data: Data("caff-one".utf8),
            format: format,
            frameCount: 1_600,
            durationMilliseconds: 100,
            rmsLevel: 0.2
        )
        let secondChunk = AppleEncodedAudioChunk(
            data: Data("caff-two".utf8),
            format: format,
            frameCount: 3_200,
            durationMilliseconds: 200,
            rmsLevel: 0.3
        )

        _ = try await recorder.persist(firstChunk, chunkID: UUID())
        _ = try await recorder.persist(secondChunk, chunkID: UUID())

        let snapshot = await writer.snapshot()
        XCTAssertEqual(await recorder.currentSequence(), 2)
        XCTAssertEqual(
            snapshot.events,
            [
                "open:0",
                "write:8",
                "close:100",
                "open:1",
                "write:8",
                "close:200",
            ]
        )
        XCTAssertEqual(snapshot.assetIDs, [assetID, assetID])
        XCTAssertEqual(snapshot.recordingIDs, [recordingID, recordingID])
    }

    func testEncodedChunkRecorderRejectsEmptyChunksBeforeOpeningWriter() async throws {
        let writer = RecordingChunkWriterSpy()
        let recorder = AppleEncodedChunkRecorder(
            writer: writer,
            recordingID: UUID(),
            assetID: UUID()
        )
        let chunk = AppleEncodedAudioChunk(
            data: Data(),
            format: AppleAudioFormatDescription(
                sampleRate: 16_000,
                channelCount: 1,
                commonFormat: "pcmFormatFloat32",
                interleaved: false
            ),
            frameCount: 0,
            durationMilliseconds: 0,
            rmsLevel: 0
        )

        do {
            _ = try await recorder.persist(chunk)
            XCTFail("empty encoded chunks should fail before writer open")
        } catch AVFoundationChunkEngineError.emptyEncodedChunk {
            XCTAssertEqual(await writer.snapshot().events, [])
        }
    }
}

private actor RecordingChunkWriterSpy: AppleAudioCaptureChunkWriting {
    struct Snapshot: Equatable {
        var events: [String]
        var assetIDs: [UUID]
        var recordingIDs: [UUID]
    }

    private var events: [String] = []
    private var assetIDs: [UUID] = []
    private var recordingIDs: [UUID] = []
    private var activeChunk: (recordingID: UUID, assetID: UUID, sequence: Int, chunkID: UUID)?

    func createSession(
        descriptor: RecordingDescriptor,
        productPolicy: RecordingProductPolicy,
        transferRoute: TransferRoute,
        at date: Date
    ) async throws -> LocalRecordingManifest {
        try LocalRecordingManifest(
            descriptor: descriptor,
            productPolicy: productPolicy,
            transferRoute: transferRoute,
            createdAt: date,
            updatedAt: date
        )
    }

    func openChunk(
        recordingID: UUID,
        assetID: UUID,
        sequence: Int,
        chunkID: UUID,
        at date: Date
    ) async throws {
        activeChunk = (
            recordingID: recordingID,
            assetID: assetID,
            sequence: sequence,
            chunkID: chunkID
        )
        recordingIDs.append(recordingID)
        assetIDs.append(assetID)
        events.append("open:\(sequence)")
    }

    func write(
        _ data: Data,
        to recordingID: UUID,
        at date: Date
    ) async throws {
        events.append("write:\(data.count)")
    }

    func closeChunk(
        recordingID: UUID,
        durationMilliseconds: Int64,
        at date: Date
    ) async throws -> AudioChunkDescriptor {
        guard let activeChunk else {
            throw AVFoundationChunkEngineError.engineNotRunning
        }
        events.append("close:\(durationMilliseconds)")
        self.activeChunk = nil
        return try AudioChunkDescriptor(
            id: activeChunk.chunkID,
            assetID: activeChunk.assetID,
            sequence: activeChunk.sequence,
            byteCount: 8,
            durationMilliseconds: durationMilliseconds,
            checksum: "sha256:test",
            createdAt: date,
            persistenceState: .verified
        )
    }

    func finalizeRecording(
        recordingID: UUID,
        endedAt: Date,
        durationMilliseconds: Int64
    ) async throws -> LocalRecordingManifest {
        let descriptor = RecordingDescriptor(
            clientRecordingID: recordingID,
            sourcePlatform: .macOS,
            mode: .meeting,
            startedAt: endedAt.addingTimeInterval(-Double(durationMilliseconds) / 1_000),
            endedAt: endedAt,
            durationMilliseconds: durationMilliseconds
        )
        return try LocalRecordingManifest(
            descriptor: descriptor,
            productPolicy: RecordingMode.meeting.defaultProductPolicy,
            localState: .finalized,
            createdAt: descriptor.startedAt,
            updatedAt: endedAt
        )
    }

    func snapshot() -> Snapshot {
        Snapshot(
            events: events,
            assetIDs: assetIDs,
            recordingIDs: recordingIDs
        )
    }
}
#endif
