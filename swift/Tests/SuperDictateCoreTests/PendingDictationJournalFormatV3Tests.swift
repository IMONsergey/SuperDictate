import Foundation
import XCTest
@testable import SuperDictateCore

extension ProductStateTests {
    func testPendingJournalV3KeepsLegacyHeaderByteCompatible() throws {
        let data = SuperDictatePendingJournalHeaderCodec.legacyHeader(
            sampleRate: 16_000,
            floatSize: 4
        )
        XCTAssertEqual(data.count, 16)
        XCTAssertEqual(Array(data.prefix(4)), Array("SDAR".utf8))
        XCTAssertEqual(Array(data[4..<8]), [1, 0, 0, 0])
        XCTAssertEqual(Array(data[8..<12]), [0x80, 0x3e, 0, 0])
        XCTAssertEqual(Array(data[12..<16]), [4, 0, 0, 0])

        let decoded = try SuperDictatePendingJournalHeaderCodec.decode(
            data,
            expectedSampleRate: 16_000,
            expectedFloatSize: 4
        )
        XCTAssertEqual(decoded.version, 1)
        XCTAssertEqual(decoded.headerSize, 16)
        XCTAssertNil(decoded.metadata)
    }

    func testPendingJournalV3MetadataHeaderRoundTripsUUIDDateAndPayloadOffset() throws {
        let id = UUID(uuidString: "01234567-89AB-CDEF-0123-456789ABCDEF")!
        let createdAt = Date(timeIntervalSince1970: 1_770_000_000.125)
        let metadata = SuperDictatePendingJournalMetadata(
            recordingID: id,
            createdAt: createdAt
        )
        var data = try SuperDictatePendingJournalHeaderCodec.metadataHeader(
            sampleRate: 16_000,
            floatSize: 4,
            metadata: metadata
        )
        XCTAssertEqual(data.count, 40)

        let payload = Data([1, 2, 3, 4, 5, 6, 7, 8])
        data.append(payload)
        let decoded = try SuperDictatePendingJournalHeaderCodec.decode(
            data,
            expectedSampleRate: 16_000,
            expectedFloatSize: 4
        )
        XCTAssertEqual(decoded.version, 2)
        XCTAssertEqual(decoded.headerSize, 40)
        XCTAssertEqual(decoded.metadata, metadata)
        XCTAssertEqual(
            Data(try SuperDictatePendingJournalHeaderCodec.payload(
                from: data,
                decodedHeader: decoded
            )),
            payload
        )
    }

    func testPendingJournalV3RejectsNonFiniteTimestampBeforeWritingHeader() {
        let invalid = SuperDictatePendingJournalMetadata(
            recordingID: UUID(),
            createdAt: Date(timeIntervalSince1970: .infinity)
        )
        XCTAssertThrowsError(
            try SuperDictatePendingJournalHeaderCodec.metadataHeader(
                sampleRate: 16_000,
                floatSize: 4,
                metadata: invalid
            )
        ) { error in
            XCTAssertEqual(
                error as? SuperDictatePendingJournalHeaderError,
                .invalidTimestamp
            )
        }
    }

    func testPendingJournalV3RejectsNonFiniteTimestampWhenDecodingTamperedHeader() throws {
        var data = try SuperDictatePendingJournalHeaderCodec.metadataHeader(
            sampleRate: 16_000,
            floatSize: 4,
            metadata: SuperDictatePendingJournalMetadata(
                recordingID: UUID(),
                createdAt: Date(timeIntervalSince1970: 100)
            )
        )
        let bits = Double.infinity.bitPattern.littleEndian
        withUnsafeBytes(of: bits) { bytes in
            data.replaceSubrange(32..<40, with: bytes)
        }

        XCTAssertThrowsError(
            try SuperDictatePendingJournalHeaderCodec.decode(
                data,
                expectedSampleRate: 16_000,
                expectedFloatSize: 4
            )
        ) { error in
            XCTAssertEqual(
                error as? SuperDictatePendingJournalHeaderError,
                .invalidTimestamp
            )
        }
    }

    func testPendingJournalV3RejectsTruncationAndUnexpectedAudioFormat() throws {
        let metadata = SuperDictatePendingJournalMetadata(
            recordingID: UUID(),
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let complete = try SuperDictatePendingJournalHeaderCodec.metadataHeader(
            sampleRate: 16_000,
            floatSize: 4,
            metadata: metadata
        )

        XCTAssertThrowsError(
            try SuperDictatePendingJournalHeaderCodec.decode(
                Data(complete.prefix(39)),
                expectedSampleRate: 16_000,
                expectedFloatSize: 4
            )
        ) { error in
            XCTAssertEqual(error as? SuperDictatePendingJournalHeaderError, .truncated)
        }

        let wrongFormat = SuperDictatePendingJournalHeaderCodec.legacyHeader(
            sampleRate: 8_000,
            floatSize: 2
        )
        XCTAssertThrowsError(
            try SuperDictatePendingJournalHeaderCodec.decode(
                wrongFormat,
                expectedSampleRate: 16_000,
                expectedFloatSize: 4
            )
        ) { error in
            XCTAssertEqual(
                error as? SuperDictatePendingJournalHeaderError,
                .invalidSampleRate(8_000)
            )
        }
    }

    func testPendingJournalV3RejectsUnknownVersionAndBadMagic() {
        var unknown = SuperDictatePendingJournalHeaderCodec.legacyHeader(
            sampleRate: 16_000,
            floatSize: 4
        )
        unknown[4] = 99
        XCTAssertThrowsError(
            try SuperDictatePendingJournalHeaderCodec.decode(
                unknown,
                expectedSampleRate: 16_000,
                expectedFloatSize: 4
            )
        ) { error in
            XCTAssertEqual(
                error as? SuperDictatePendingJournalHeaderError,
                .unsupportedVersion(99)
            )
        }

        var badMagic = SuperDictatePendingJournalHeaderCodec.legacyHeader(
            sampleRate: 16_000,
            floatSize: 4
        )
        badMagic[0] = 0
        XCTAssertThrowsError(
            try SuperDictatePendingJournalHeaderCodec.decode(
                badMagic,
                expectedSampleRate: 16_000,
                expectedFloatSize: 4
            )
        ) { error in
            XCTAssertEqual(error as? SuperDictatePendingJournalHeaderError, .invalidMagic)
        }
    }
}
