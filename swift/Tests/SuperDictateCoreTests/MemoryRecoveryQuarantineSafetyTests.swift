import Foundation
import XCTest
@testable import SuperDictateCore

extension ProductStateTests {
    func testMemoryRecoveryRejectsSymlinkQuarantineBeforeMovingSource() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperDictateQuarantineSymlink-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try JSONSuperDictateMemoryPackageStore(rootDirectory: root)
        let recordingID = UUID()
        _ = try await store.createPackage(recordingID: recordingID)

        let sourceDirectory = await store.audioDirectory(
            recordingID: recordingID,
            source: .system
        )
        let chunkID = UUID()
        let sourceURL = sourceDirectory.appendingPathComponent(
            URL(
                fileURLWithPath: SuperDictateMemoryAudioChunk.canonicalRelativePath(
                    source: .system,
                    sequence: 0,
                    chunkID: chunkID
                )
            ).lastPathComponent
        )
        var sourceBytes = Data("caff".utf8)
        sourceBytes.append(Data("undocumented".utf8))
        try sourceBytes.write(to: sourceURL)

        let quarantineURL = await store.quarantineDirectory(recordingID: recordingID)
        try FileManager.default.removeItem(at: quarantineURL)
        let outside = root.appendingPathComponent("outside-quarantine", isDirectory: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: quarantineURL,
            withDestinationURL: outside
        )

        do {
            _ = try await SuperDictateMemoryPackageRecovery(store: store)
                .recover(recordingID: recordingID)
            XCTFail("a symlink quarantine directory must abort recovery")
        } catch {
            XCTAssertEqual(
                error as? SuperDictateMemoryRecoveryError,
                .unsafeFileType("quarantine")
            )
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path))
        XCTAssertTrue(
            try FileManager.default.contentsOfDirectory(atPath: outside.path).isEmpty
        )
    }
}
