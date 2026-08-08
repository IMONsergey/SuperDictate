import Foundation

public struct SuperDictatePendingJournalMetadata: Equatable, Sendable {
    public let recordingID: UUID
    public let createdAt: Date

    public init(recordingID: UUID, createdAt: Date) {
        self.recordingID = recordingID
        self.createdAt = createdAt
    }
}

public struct SuperDictatePendingJournalDecodedHeader: Equatable, Sendable {
    public let version: UInt32
    public let headerSize: Int
    public let metadata: SuperDictatePendingJournalMetadata?

    public init(
        version: UInt32,
        headerSize: Int,
        metadata: SuperDictatePendingJournalMetadata?
    ) {
        self.version = version
        self.headerSize = headerSize
        self.metadata = metadata
    }
}

public enum SuperDictatePendingJournalHeaderError: Error, Equatable, Sendable {
    case truncated
    case invalidMagic
    case unsupportedVersion(UInt32)
    case invalidSampleRate(UInt32)
    case invalidFloatSize(UInt32)
    case invalidTimestamp
}

/// Versioned fixed-width header for the existing crash-safe pending dictation
/// Float32 journal.
///
/// v1 (16 bytes): `SDAR` + version + sample rate + Float width.
/// v2 (40 bytes): the exact v1 prefix + UUID(16) + capture timestamp encoded as
/// a little-endian IEEE-754 Double bit pattern(8).
///
/// Raw Float32 samples remain byte-for-byte unchanged after `headerSize`. That is
/// the compatibility boundary: already-written v1 recovery files remain readable,
/// while v2 can preserve the same recording UUID and capture chronology across a
/// process crash instead of falling back to transcript-derived identity.
public enum SuperDictatePendingJournalHeaderCodec {
    public static let legacyVersion: UInt32 = 1
    public static let metadataVersion: UInt32 = 2
    public static let legacyHeaderSize = 16
    public static let metadataHeaderSize = 40

    private static let magic = Data("SDAR".utf8)

    public static func legacyHeader(
        sampleRate: UInt32,
        floatSize: UInt32
    ) -> Data {
        var data = magic
        appendUInt32LE(legacyVersion, to: &data)
        appendUInt32LE(sampleRate, to: &data)
        appendUInt32LE(floatSize, to: &data)
        precondition(data.count == legacyHeaderSize)
        return data
    }

    public static func metadataHeader(
        sampleRate: UInt32,
        floatSize: UInt32,
        metadata: SuperDictatePendingJournalMetadata
    ) throws -> Data {
        let timestamp = metadata.createdAt.timeIntervalSince1970
        guard timestamp.isFinite else {
            throw SuperDictatePendingJournalHeaderError.invalidTimestamp
        }

        var data = magic
        appendUInt32LE(metadataVersion, to: &data)
        appendUInt32LE(sampleRate, to: &data)
        appendUInt32LE(floatSize, to: &data)

        var uuid = metadata.recordingID.uuid
        withUnsafeBytes(of: &uuid) { data.append(contentsOf: $0) }
        appendUInt64LE(timestamp.bitPattern, to: &data)
        precondition(data.count == metadataHeaderSize)
        return data
    }

    public static func decode(
        _ data: Data,
        expectedSampleRate: UInt32,
        expectedFloatSize: UInt32
    ) throws -> SuperDictatePendingJournalDecodedHeader {
        guard data.count >= legacyHeaderSize else {
            throw SuperDictatePendingJournalHeaderError.truncated
        }
        guard data.prefix(4) == magic else {
            throw SuperDictatePendingJournalHeaderError.invalidMagic
        }

        let version = readUInt32LE(data, offset: 4)
        let sampleRate = readUInt32LE(data, offset: 8)
        let floatSize = readUInt32LE(data, offset: 12)

        guard sampleRate == expectedSampleRate else {
            throw SuperDictatePendingJournalHeaderError.invalidSampleRate(sampleRate)
        }
        guard floatSize == expectedFloatSize else {
            throw SuperDictatePendingJournalHeaderError.invalidFloatSize(floatSize)
        }

        switch version {
        case legacyVersion:
            return SuperDictatePendingJournalDecodedHeader(
                version: version,
                headerSize: legacyHeaderSize,
                metadata: nil
            )

        case metadataVersion:
            guard data.count >= metadataHeaderSize else {
                throw SuperDictatePendingJournalHeaderError.truncated
            }

            let bytes = Array(data[16..<32])
            let recordingID = UUID(uuid: (
                bytes[0], bytes[1], bytes[2], bytes[3],
                bytes[4], bytes[5], bytes[6], bytes[7],
                bytes[8], bytes[9], bytes[10], bytes[11],
                bytes[12], bytes[13], bytes[14], bytes[15]
            ))
            let timestamp = Double(bitPattern: readUInt64LE(data, offset: 32))
            guard timestamp.isFinite else {
                throw SuperDictatePendingJournalHeaderError.invalidTimestamp
            }

            return SuperDictatePendingJournalDecodedHeader(
                version: version,
                headerSize: metadataHeaderSize,
                metadata: SuperDictatePendingJournalMetadata(
                    recordingID: recordingID,
                    createdAt: Date(timeIntervalSince1970: timestamp)
                )
            )

        default:
            throw SuperDictatePendingJournalHeaderError.unsupportedVersion(version)
        }
    }

    /// Payload begins exactly after the decoded versioned header. Exposing this
    /// helper keeps runtime recovery code from duplicating v1/v2 offset logic.
    public static func payload(
        from data: Data,
        decodedHeader: SuperDictatePendingJournalDecodedHeader
    ) throws -> Data.SubSequence {
        guard data.count >= decodedHeader.headerSize else {
            throw SuperDictatePendingJournalHeaderError.truncated
        }
        return data.suffix(from: decodedHeader.headerSize)
    }

    private static func appendUInt32LE(_ value: UInt32, to data: inout Data) {
        var value = value.littleEndian
        withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
    }

    private static func appendUInt64LE(_ value: UInt64, to data: inout Data) {
        var value = value.littleEndian
        withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
    }

    private static func readUInt32LE(_ data: Data, offset: Int) -> UInt32 {
        UInt32(data[offset])
            | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16)
            | (UInt32(data[offset + 3]) << 24)
    }

    private static func readUInt64LE(_ data: Data, offset: Int) -> UInt64 {
        var value: UInt64 = 0
        for index in 0..<8 {
            value |= UInt64(data[offset + index]) << UInt64(index * 8)
        }
        return value
    }
}
