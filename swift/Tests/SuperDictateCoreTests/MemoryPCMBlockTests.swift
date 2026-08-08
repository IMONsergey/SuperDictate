import Foundation
import XCTest
@testable import SuperDictateCore

extension ProductStateTests {
    func testMemoryPCMBlockPreservesSourceTimingAndShape() throws {
        let block = try SuperDictateMemoryPCMBlock(
            sampleRate: 48_000,
            channels: [
                Array(repeating: 0.25, count: 4_800),
                Array(repeating: -0.25, count: 4_800),
            ],
            sessionStartMilliseconds: 250
        )
        XCTAssertEqual(block.channelCount, 2)
        XCTAssertEqual(block.frameCount, 4_800)
        XCTAssertEqual(block.durationMilliseconds, 100)
        XCTAssertEqual(block.sessionEndMilliseconds, 350)
    }

    func testMemoryPCMBlockRejectsInvalidShapeAndSamples() {
        XCTAssertThrowsError(
            try SuperDictateMemoryPCMBlock(
                sampleRate: 0,
                channels: [[0]],
                sessionStartMilliseconds: 0
            )
        )
        XCTAssertThrowsError(
            try SuperDictateMemoryPCMBlock(
                sampleRate: 48_000,
                channels: [],
                sessionStartMilliseconds: 0
            )
        )
        XCTAssertThrowsError(
            try SuperDictateMemoryPCMBlock(
                sampleRate: 48_000,
                channels: [[0, 1], [0]],
                sessionStartMilliseconds: 0
            )
        )
        XCTAssertThrowsError(
            try SuperDictateMemoryPCMBlock(
                sampleRate: 48_000,
                channels: [[.nan]],
                sessionStartMilliseconds: 0
            )
        )
        XCTAssertThrowsError(
            try SuperDictateMemoryPCMBlock(
                sampleRate: 48_000,
                channels: [[0]],
                sessionStartMilliseconds: -1
            )
        )
    }
}
