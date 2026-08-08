from pathlib import Path

path = Path("swift/Sources/Parakey/main.swift")
text = path.read_text()
old = """    }

    private static func testDictationUsageStatistics() throws {
"""
new = """        let legacyHistoryJSON = Data(\"[{\\\"text\\\":\\\"legacy row\\\"}]\".utf8)
        let legacyHistoryDecoded = try JSONDecoder().decode(
            [TranscriptHistoryEntry].self,
            from: legacyHistoryJSON
        )
        try expect(
            legacyHistoryDecoded.first?.recordingID == nil
                && legacyHistoryDecoded.first?.createdAt == nil
                && legacyHistoryDecoded.first?.sourceAudioDurationSeconds == nil,
            equals: true,
            \"older history JSON should decode with unknown durable metadata\"
        )

        let metadataID = UUID(uuidString: \"01234567-89AB-CDEF-0123-456789ABCDEF\")!
        let metadataEntry = TranscriptHistoryEntry(
            text: \"metadata row\",
            transcriptionDurationSeconds: 0.75,
            recordingID: metadataID,
            createdAt: Date(timeIntervalSinceReferenceDate: 12_345),
            sourceAudioDurationSeconds: 8.5
        )
        let metadataRoundTrip = try JSONDecoder().decode(
            TranscriptHistoryEntry.self,
            from: JSONEncoder().encode(metadataEntry)
        )
        try expect(
            metadataRoundTrip,
            equals: metadataEntry,
            \"history Codable round-trip should preserve durable recording metadata\"
        )
    }

    private static func testDictationUsageStatistics() throws {
"""
if new in text:
    raise SystemExit("history metadata self-test is already applied")
count = text.count(old)
if count != 1:
    raise SystemExit(f"history metadata self-test insertion: expected one match, found {count}")
path.write_text(text.replace(old, new, 1))
