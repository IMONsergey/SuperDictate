import Foundation

struct ProductLibraryWiringSmokeFailure: Error, CustomStringConvertible {
    let description: String
}

@main
struct ProductLibraryWiringSmoke {
    static func main() throws {
        let arguments = CommandLine.arguments
        guard arguments.count == 3 else {
            throw ProductLibraryWiringSmokeFailure(
                description: "usage: ProductLibraryWiringSmoke <window-controller.swift> <library-coordinator.swift>"
            )
        }

        let windowSource = try String(contentsOfFile: arguments[1], encoding: .utf8)
        let librarySource = try String(contentsOfFile: arguments[2], encoding: .utf8)

        try require(
            windowSource.contains("NativeProductLibraryCoordinator"),
            "native product window must own the durable Library coordinator"
        )
        try require(
            windowSource.contains("SuperDictateMainView("),
            "controller should host the plain observable product view"
        )
        try require(
            !windowSource.contains("SuperDictateLiveMainView("),
            "controller and SwiftUI must not both own runtime polling"
        )
        try require(
            windowSource.contains("synchronizeLibrary(liveSnapshot:"),
            "every successful live snapshot refresh must schedule Library reconciliation"
        )
        try require(
            librarySource.contains("cachedArchive"),
            "Library coordinator should cache the durable archive between fast UI ticks"
        )
        try require(
            librarySource.contains("lastLiveRecordings == liveSnapshot.recordings"),
            "status-only refreshes should reuse the previous merged Library projection"
        )
        try require(
            librarySource.contains("for recording in durable where seen.insert(recording.id).inserted"),
            "durable recordings that leave recent history must remain in Library"
        )
        try require(
            !librarySource.contains("removeRecordingFromIndex"),
            "recent-history reconciliation must never infer durable Library deletion"
        )

        print("Product Library wiring smoke passed")
    }

    private static func require(
        _ condition: @autoclosure () -> Bool,
        _ message: String
    ) throws {
        guard condition() else {
            throw ProductLibraryWiringSmokeFailure(description: message)
        }
    }
}
