import Foundation
import XCTest
@testable import SuperDictateCore

extension ProductStateTests {
    func testPendingJournalV1HeaderRemainsReadable() throws {
        let data = SuperDictatePendingJournalHeaderCodec.legacyHeader(
            sampleRate: 16_000,
            floatSize: 4
        )
        XCTAssertEqual(data.count, 16)

        let decoded = try SuperDictatePendingJournalHeaderCodec.decode(
            data,
            expectedSampleRate: 16_000,
            expectedFloatSize: 4
        )
        XCTAssertEqual(decoded.version, 1)
        XCTAssertEqual(decoded.headerSize, 16)
        XCTAssertNil(decoded.metadata)
    }

    func testPendingJournalV2MetadataRoundTripsExactly() throws {
        let id = UUID(uuidString: "01234567-89AB-CDEF-0123-456789ABCDEF")!
        let createdAt = Date(timeIntervalSince1970: 1_770_000_000.125)
        let metadata = SuperDictatePendingJournalMetadata(
            recordingID: id,
            createdAt: createdAt
        )
        var data = SuperDictatePendingJournalHeaderCodec.metadataHeader(
            sampleRate: 16_000,
            floatSize: 4,
            metadata: metadata
        )
        // Decoder reads only the versioned header and is intentionally tolerant
        // of the raw Float payload that follows it.
        data.append(contentsOf: [0, 0, 0, 0])

        let decoded = try SuperDictatePendingJournalHeaderCodec.decode(
            data,
            expectedSampleRate: 16_000,
            expectedFloatSize: 4
        )
        XCTAssertEqual(decoded.version, 2)
        XCTAssertEqual(decoded.headerSize, 40)
        XCTAssertEqual(decoded.metadata, metadata)
    }

    func testPendingJournalV2RejectsTruncatedMetadataHeader() {
        let metadata = SuperDictatePendingJournalMetadata(
            recordingID: UUID(),
            createdAt: Date()
        )
        let complete = SuperDictatePendingJournalHeaderCodec.metadataHeader(
            sampleRate: 16_000,
            floatSize: 4,
            metadata: metadata
        )

        XCTAssertThrowsError(
            try SuperDictatePendingJournalHeaderCodec.decode(
                complete.prefix(39),
                expectedSampleRate: 16_000,
                expectedFloatSize: 4
            )
        ) { error in
            XCTAssertEqual(error as? SuperDictatePendingJournalHeaderError, .truncated)
        }
    }

    func testPendingJournalHeaderRejectsWrongAudioFormat() {
        let data = SuperDictatePendingJournalHeaderCodec.legacyHeader(
            sampleRate: 8_000,
            floatSize: 2
        )

        XCTAssertThrowsError(
            try SuperDictatePendingJournalHeaderCodec.decode(
                data,
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

    func testPendingJournalHeaderRejectsUnknownVersion() throws {
        var data = SuperDictatePendingJournalHeaderCodec.legacyHeader(
            sampleRate: 16_000,
            floatSize: 4
        )
        data[4] = 99
        data[5] = 0
        data[6] = 0
        data[7] = 0

        XCTAssertThrowsError(
            try SuperDictatePendingJournalHeaderCodec.decode(
                data,
                expectedSampleRate: 16_000,
                expectedFloatSize: 4
            )
        ) { error in
            XCTAssertEqual(
                error as? SuperDictatePendingJournalHeaderError,
                .unsupportedVersion(99)
            )
        }
    }
}
