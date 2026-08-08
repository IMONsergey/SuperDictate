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

    public init(version: UInt32, headerSize: Int, metadata: SuperDictatePendingJournalMetadata?) {
        self.version = version
        self.headerSize = headerSize
        self.metadata = metadata
    }
}

public enum SuperDictatePendingJournalHeaderError: Error, Equatable {
    case truncated
    case invalidMagic
    case unsupportedVersion(UInt32)
    case invalidSampleRate(UInt32)
    case invalidFloatSize(UInt32)
    case invalidTimestamp
}

/// Versioned binary header for crash-safe pending dictation audio.
///
/// v1 (16 bytes): `SDAR` + version + sample rate + Float width.
/// v2 (40 bytes): the complete v1 prefix + UUID(16) + capture Date as a
/// little-endian IEEE-754 Double bit pattern(8).
///
/// The raw Float32 audio payload remains unchanged and begins immediately after
/// the version-specific `headerSize`, so v1 files stay readable after v2 ships.
public enum SuperDictatePendingJournalHeaderCodec {
    public static let legacyVersion: UInt32 = 1
    public static let metadataVersion: UInt32 = 2
    public static let legacyHeaderSize = 16
    public static let metadataHeaderSize = 40

    private static let magic = Data("SDAR".utf8)

    public static func legacyHeader(sampleRate: UInt32, floatSize: UInt32) -> Data {
        var data = magic
        appendUInt32LE(legacyVersion, to: &data)
        appendUInt32LE(sampleRate, to: &data)
        appendUInt32LE(floatSize, to: &data)
        return data
    }

    public static func metadataHeader(
        sampleRate: UInt32,
        floatSize: UInt32,
        metadata: SuperDictatePendingJournalMetadata
    ) -> Data {
        var data = magic
        appendUInt32LE(metadataVersion, to: &data)
        appendUInt32LE(sampleRate, to: &data)
        appendUInt32LE(floatSize, to: &data)

        var uuid = metadata.recordingID.uuid
        withUnsafeBytes(of: &uuid) { data.append(contentsOf: $0) }
        appendUInt64LE(metadata.createdAt.timeIntervalSince1970.bitPattern, to: &data)
        precondition(data.count == metadataHeaderSize)
        return data
    }

    public static func decode(
        _ data: Data,
        expectedSampleRate: UInt32,
        expectedFloatSize: UInt32
    ) throws -> SuperDictatePendingJournalDecodedHeader {
        guard data.count >= legacyHeaderSize else { throw SuperDictatePendingJournalHeaderError.truncated }
        guard data.prefix(4) == magic else { throw SuperDictatePendingJournalHeaderError.invalidMagic }

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
            let uuidBytes = Array(data[16..<32])
            let id = UUID(uuid: (
                uuidBytes[0], uuidBytes[1], uuidBytes[2], uuidBytes[3],
                uuidBytes[4], uuidBytes[5], uuidBytes[6], uuidBytes[7],
                uuidBytes[8], uuidBytes[9], uuidBytes[10], uuidBytes[11],
                uuidBytes[12], uuidBytes[13], uuidBytes[14], uuidBytes[15]
            ))
            let timestamp = Double(bitPattern: readUInt64LE(data, offset: 32))
            guard timestamp.isFinite else {
                throw SuperDictatePendingJournalHeaderError.invalidTimestamp
            }
            return SuperDictatePendingJournalDecodedHeader(
                version: version,
                headerSize: metadataHeaderSize,
                metadata: SuperDictatePendingJournalMetadata(
                    recordingID: id,
                    createdAt: Date(timeIntervalSince1970: timestamp)
                )
            )

        default:
            throw SuperDictatePendingJournalHeaderError.unsupportedVersion(version)
        }
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
