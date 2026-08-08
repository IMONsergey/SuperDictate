import Foundation
import XCTest
@testable import SuperDictateCore

extension ProductStateTests {
    func testLegacyRecordingWithoutCaptureKindDefaultsToInstantDictationSemantically() throws {
        let id = UUID(uuidString: "01234567-89AB-CDEF-0123-456789ABCDEF")!
        let json = """
        {
          "id":"\(id.uuidString)",
          "title":"Legacy",
          "transcript":"Legacy transcript",
          "people":[],
          "requiresAttention":false
        }
        """
        let recording = try JSONDecoder().decode(
            SuperDictateRecording.self,
            from: Data(json.utf8)
        )

        XCTAssertNil(recording.captureKind)
        XCTAssertEqual(recording.effectiveCaptureKind, .instantDictation)
    }

    func testExplicitCaptureKindsRoundTrip() throws {
        for kind in SuperDictateCaptureKind.allCases {
            let source = SuperDictateRecording(
                title: "Kind",
                transcript: "Transcript",
                captureKind: kind
            )
            let decoded = try JSONDecoder().decode(
                SuperDictateRecording.self,
                from: JSONEncoder().encode(source)
            )
            XCTAssertEqual(decoded, source)
            XCTAssertEqual(decoded.effectiveCaptureKind, kind)
        }
    }
}
