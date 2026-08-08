import Foundation

struct PendingDictationJournalMetadata: Equatable, Sendable {
    let recordingID: UUID
    let createdAt: Date
}

struct PendingDictationJournalDecodedHeader: Equatable, Sendable {
    let version: UInt32
    let headerSize: Int
    let metadata: PendingDictationJournalMetadata?
}

enum PendingDictationJournalHeaderCodecError: Error, Equatable {
    case truncated
    case invalidMagic
    case unsupportedVersion(UInt32)
    case invalidSampleRate(UInt32)
    case invalidFloatSize(UInt32)
    case invalidTimestamp
}

/// Binary header codec for crash-safe pending audio journals.
///
/// v1 layout (16 bytes):
/// - magic: 4 bytes, ASCII `SDAR`
/// - version: UInt32 LE
/// - sample rate: UInt32 LE
/// - Float sample width: UInt32 LE
///
/// v2 layout (40 bytes):
/// - the complete v1 prefix
/// - recording UUID: 16 raw bytes
/// - capture timestamp: IEEE-754 Double seconds since Unix epoch, UInt64 LE bit pattern
///
/// Audio payload remains raw Float32 samples immediately after the version-specific
/// header. Keeping the v1 prefix byte-for-byte compatible makes the format easy to
/// identify and lets the recovery loader continue accepting already-written v1 files.
enum PendingDictationJournalHeaderCodec {
    static let legacyVersion: UInt32 = 1
    static let metadataVersion: UInt32 = 2
    static let legacyHeaderSize = 16
    static let metadataHeaderSize = 40

    private static let magic = Data("SDAR".utf8)

    static func legacyHeader(
        sampleRate: UInt32,
        floatSize: UInt32
    ) -> Data {
        var data = magic
        appendUInt32LE(legacyVersion, to: &data)
        appendUInt32LE(sampleRate, to: &data)
        appendUInt32LE(floatSize, to: &data)
        return data
    }

    static func metadataHeader(
        sampleRate: UInt32,
        floatSize: UInt32,
        metadata: PendingDictationJournalMetadata
    ) -> Data {
        var data = magic
        appendUInt32LE(metadataVersion, to: &data)
        appendUInt32LE(sampleRate, to: &data)
        appendUInt32LE(floatSize, to: &data)

        var uuid = metadata.recordingID.uuid
        withUnsafeBytes(of: &uuid) { bytes in
            data.append(contentsOf: bytes)
        }

        appendUInt64LE(metadata.createdAt.timeIntervalSince1970.bitPattern, to: &data)
        precondition(data.count == metadataHeaderSize)
        return data
    }

    static func decode(
        _ data: Data,
        expectedSampleRate: UInt32,
        expectedFloatSize: UInt32
    ) throws -> PendingDictationJournalDecodedHeader {
        guard data.count >= legacyHeaderSize else {
            throw PendingDictationJournalHeaderCodecError.truncated
        }
        guard data.prefix(4) == magic else {
            throw PendingDictationJournalHeaderCodecError.invalidMagic
        }

        let version = readUInt32LE(data, offset: 4)
        let sampleRate = readUInt32LE(data, offset: 8)
        let floatSize = readUInt32LE(data, offset: 12)

        guard sampleRate == expectedSampleRate else {
            throw PendingDictationJournalHeaderCodecError.invalidSampleRate(sampleRate)
        }
        guard floatSize == expectedFloatSize else {
            throw PendingDictationJournalHeaderCodecError.invalidFloatSize(floatSize)
        }

        switch version {
        case legacyVersion:
            return PendingDictationJournalDecodedHeader(
                version: version,
                headerSize: legacyHeaderSize,
                metadata: nil
            )

        case metadataVersion:
            guard data.count >= metadataHeaderSize else {
                throw PendingDictationJournalHeaderCodecError.truncated
            }

            let uuidBytes = Array(data[16..<32])
            let recordingID = UUID(uuid: (
                uuidBytes[0], uuidBytes[1], uuidBytes[2], uuidBytes[3],
                uuidBytes[4], uuidBytes[5], uuidBytes[6], uuidBytes[7],
                uuidBytes[8], uuidBytes[9], uuidBytes[10], uuidBytes[11],
                uuidBytes[12], uuidBytes[13], uuidBytes[14], uuidBytes[15]
            ))
            let timestampBits = readUInt64LE(data, offset: 32)
            let timestamp = Double(bitPattern: timestampBits)
            guard timestamp.isFinite else {
                throw PendingDictationJournalHeaderCodecError.invalidTimestamp
            }

            return PendingDictationJournalDecodedHeader(
                version: version,
                headerSize: metadataHeaderSize,
                metadata: PendingDictationJournalMetadata(
                    recordingID: recordingID,
                    createdAt: Date(timeIntervalSince1970: timestamp)
                )
            )

        default:
            throw PendingDictationJournalHeaderCodecError.unsupportedVersion(version)
        }
    }

    private static func appendUInt32LE(_ value: UInt32, to data: inout Data) {
        let little = value.littleEndian
        withUnsafeBytes(of: little) { bytes in
            data.append(contentsOf: bytes)
        }
    }

    private static func appendUInt64LE(_ value: UInt64, to data: inout Data) {
        let little = value.littleEndian
        withUnsafeBytes(of: little) { bytes in
            data.append(contentsOf: bytes)
        }
    }

    private static func readUInt32LE(_ data: Data, offset: Int) -> UInt32 {
        let bytes = data
        return UInt32(bytes[offset])
            | (UInt32(bytes[offset + 1]) << 8)
            | (UInt32(bytes[offset + 2]) << 16)
            | (UInt32(bytes[offset + 3]) << 24)
    }

    private static func readUInt64LE(_ data: Data, offset: Int) -> UInt64 {
        var value: UInt64 = 0
        for index in 0..<8 {
            value |= UInt64(data[offset + index]) << UInt64(index * 8)
        }
        return value
    }
}
