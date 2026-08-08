import Foundation
import XCTest
@testable import SuperDictateCore

extension ProductStateTests {
    func testPreparedRecoveryEventRejectsChecksumAndCommittedRequiresIt() throws {
        let recordingID = UUID()
        let chunkID = UUID()
        let path = SuperDictateMemoryAudioChunk.canonicalRelativePath(
            source: .microphone,
            sequence: 0,
            chunkID: chunkID
        )
        let sha = String(repeating: "a", count: 64)

        XCTAssertThrowsError(
            try SuperDictateMemoryRecoveryEvent(
                kind: .chunkPrepared,
                recordingID: recordingID,
                chunkID: chunkID,
                source: .microphone,
                sequence: 0,
                relativePath: path,
                sessionStartMilliseconds: 0,
                sessionEndMilliseconds: 100,
                sampleRate: 48_000,
                channelCount: 1,
                byteLength: 100,
                sha256: sha
            )
        ) { error in
            XCTAssertEqual(
                error as? SuperDictateMemoryRecoveryJournalError,
                .invalidSHA256(sha)
            )
        }

        XCTAssertThrowsError(
            try SuperDictateMemoryRecoveryEvent(
                kind: .chunkCommitted,
                recordingID: recordingID,
                chunkID: chunkID,
                source: .microphone,
                sequence: 0,
                relativePath: path,
                sessionStartMilliseconds: 0,
                sessionEndMilliseconds: 100,
                sampleRate: 48_000,
                channelCount: 1,
                byteLength: 100
            )
        ) { error in
            XCTAssertEqual(
                error as? SuperDictateMemoryRecoveryJournalError,
                .invalidSHA256("")
            )
        }

        let committed = try SuperDictateMemoryRecoveryEvent(
            kind: .chunkCommitted,
            recordingID: recordingID,
            chunkID: chunkID,
            source: .microphone,
            sequence: 0,
            relativePath: path,
            sessionStartMilliseconds: 0,
            sessionEndMilliseconds: 100,
            sampleRate: 48_000,
            channelCount: 1,
            byteLength: 100,
            sha256: sha
        )
        XCTAssertEqual(committed.sha256, sha)
    }
}
