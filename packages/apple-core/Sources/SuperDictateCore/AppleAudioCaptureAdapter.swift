#if canImport(AVFoundation)
import AVFoundation
#endif
import Foundation

public enum AppleAudioCapturePermission: String, Codable, CaseIterable, Sendable {
    case unknown
    case notDetermined = "not_determined"
    case denied
    case granted
}

public enum AppleAudioCaptureState: String, Codable, CaseIterable, Sendable {
    case idle
    case awaitingPermission = "awaiting_permission"
    case recording
    case paused
    case interrupted
    case stopping
    case ready
    case failed
}

public enum AppleAudioCaptureRouteChangeReason: String, Codable, CaseIterable, Sendable {
    case unknown
    case newDeviceAvailable = "new_device_available"
    case oldDeviceUnavailable = "old_device_unavailable"
    case categoryChange = "category_change"
    case override
    case wakeFromSleep = "wake_from_sleep"
    case noSuitableRoute = "no_suitable_route"
}

public struct AppleAudioCaptureFailure: Error, Codable, Equatable, Sendable {
    public let code: String
    public let message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }

    public static let permissionDenied = AppleAudioCaptureFailure(
        code: "permission_denied",
        message: "Recording permission is denied."
    )

    public static let invalidState = AppleAudioCaptureFailure(
        code: "invalid_state",
        message: "The requested capture transition is not valid from the current state."
    )

    public static let invalidMarkerOffset = AppleAudioCaptureFailure(
        code: "invalid_marker_offset",
        message: "Marker offsets must not be negative."
    )
}

public enum AppleAudioCaptureEvent: Equatable, Sendable {
    case startRequested
    case permissionResolved(AppleAudioCapturePermission)
    case pauseRequested
    case resumeRequested
    case stopRequested
    case writerFinalized
    case interruptionBegan
    case interruptionEnded(shouldResume: Bool)
    case routeChanged(AppleAudioCaptureRouteChangeReason)
    case markerRequested(kind: RecordingMarkerKind, offsetMilliseconds: Int64, note: String?)
    case failure(AppleAudioCaptureFailure)
}

public enum AppleAudioCaptureEffect: Equatable, Sendable {
    case requestPermission
    case activateSession
    case deactivateSession
    case beginChunkedRecording
    case pauseEngine
    case resumeEngine
    case stopEngine
    case finalizeRecording
    case refreshRoute(AppleAudioCaptureRouteChangeReason)
    case emitMarker(kind: RecordingMarkerKind, offsetMilliseconds: Int64, note: String?)
    case surfaceFailure(AppleAudioCaptureFailure)
}

public struct AppleAudioCaptureCoordinator: Equatable, Sendable {
    public private(set) var state: AppleAudioCaptureState
    public private(set) var permission: AppleAudioCapturePermission
    public private(set) var routeChangeCount: Int
    private var shouldResumeAfterInterruption: Bool

    public init(
        state: AppleAudioCaptureState = .idle,
        permission: AppleAudioCapturePermission = .unknown,
        routeChangeCount: Int = 0
    ) {
        self.state = state
        self.permission = permission
        self.routeChangeCount = routeChangeCount
        self.shouldResumeAfterInterruption = false
    }

    public mutating func handle(_ event: AppleAudioCaptureEvent) -> [AppleAudioCaptureEffect] {
        switch event {
        case .startRequested:
            return handleStartRequested()

        case .permissionResolved(let permission):
            self.permission = permission
            guard permission == .granted else {
                state = .failed
                return [.surfaceFailure(.permissionDenied)]
            }
            guard state == .awaitingPermission || state == .idle || state == .ready else {
                return []
            }
            state = .recording
            return [.activateSession, .beginChunkedRecording]

        case .pauseRequested:
            guard state == .recording else {
                return [.surfaceFailure(.invalidState)]
            }
            state = .paused
            return [.pauseEngine]

        case .resumeRequested:
            guard state == .paused else {
                return [.surfaceFailure(.invalidState)]
            }
            state = .recording
            return [.resumeEngine]

        case .stopRequested:
            guard state == .recording || state == .paused || state == .interrupted else {
                return [.surfaceFailure(.invalidState)]
            }
            shouldResumeAfterInterruption = false
            state = .stopping
            return [.stopEngine, .finalizeRecording]

        case .writerFinalized:
            guard state == .stopping else {
                return [.surfaceFailure(.invalidState)]
            }
            state = .ready
            return [.deactivateSession]

        case .interruptionBegan:
            guard state == .recording || state == .paused else {
                return []
            }
            shouldResumeAfterInterruption = state == .recording
            state = .interrupted
            return [.pauseEngine]

        case .interruptionEnded(let shouldResume):
            guard state == .interrupted else {
                return []
            }
            if shouldResume && shouldResumeAfterInterruption {
                shouldResumeAfterInterruption = false
                state = .recording
                return [.activateSession, .resumeEngine]
            }
            shouldResumeAfterInterruption = false
            state = .paused
            return []

        case .routeChanged(let reason):
            routeChangeCount += 1
            return [.refreshRoute(reason)]

        case .markerRequested(let kind, let offsetMilliseconds, let note):
            guard offsetMilliseconds >= 0 else {
                return [.surfaceFailure(.invalidMarkerOffset)]
            }
            guard state == .recording || state == .paused || state == .interrupted else {
                return [.surfaceFailure(.invalidState)]
            }
            return [
                .emitMarker(
                    kind: kind,
                    offsetMilliseconds: offsetMilliseconds,
                    note: note
                ),
            ]

        case .failure(let failure):
            state = .failed
            shouldResumeAfterInterruption = false
            return [.surfaceFailure(failure)]
        }
    }

    private mutating func handleStartRequested() -> [AppleAudioCaptureEffect] {
        switch permission {
        case .granted:
            guard state == .idle || state == .ready else {
                return [.surfaceFailure(.invalidState)]
            }
            state = .recording
            return [.activateSession, .beginChunkedRecording]

        case .notDetermined, .unknown:
            guard state == .idle || state == .ready else {
                return [.surfaceFailure(.invalidState)]
            }
            state = .awaitingPermission
            return [.requestPermission]

        case .denied:
            state = .failed
            return [.surfaceFailure(.permissionDenied)]
        }
    }
}

public protocol AppleAudioSessionControlling: Sendable {
    func currentRecordPermission() async -> AppleAudioCapturePermission
    func requestRecordPermission() async -> AppleAudioCapturePermission
    func activateForRecording() async throws
    func deactivateAfterRecording() async throws
}

public protocol AppleAudioCaptureChunkWriting: Sendable {
    func createSession(
        descriptor: RecordingDescriptor,
        productPolicy: RecordingProductPolicy,
        transferRoute: TransferRoute,
        at date: Date
    ) async throws -> LocalRecordingManifest

    func openChunk(
        recordingID: UUID,
        assetID: UUID,
        sequence: Int,
        chunkID: UUID,
        at date: Date
    ) async throws

    func write(
        _ data: Data,
        to recordingID: UUID,
        at date: Date
    ) async throws

    func closeChunk(
        recordingID: UUID,
        durationMilliseconds: Int64,
        at date: Date
    ) async throws -> AudioChunkDescriptor

    func finalizeRecording(
        recordingID: UUID,
        endedAt: Date,
        durationMilliseconds: Int64
    ) async throws -> LocalRecordingManifest
}

extension ChunkFileWriter: AppleAudioCaptureChunkWriting {}

#if canImport(AVFoundation) && (os(iOS) || os(watchOS))
public final class AVFoundationAudioSessionController: AppleAudioSessionControlling, @unchecked Sendable {
    private let session: AVAudioSession

    public init(session: AVAudioSession = .sharedInstance()) {
        self.session = session
    }

    public func currentRecordPermission() async -> AppleAudioCapturePermission {
        Self.mapRecordPermission(session.recordPermission)
    }

    public func requestRecordPermission() async -> AppleAudioCapturePermission {
        await withCheckedContinuation { continuation in
            session.requestRecordPermission { granted in
                continuation.resume(returning: granted ? .granted : .denied)
            }
        }
    }

    public func activateForRecording() async throws {
        #if os(iOS)
        try session.setCategory(
            .record,
            mode: .spokenAudio,
            options: [.allowBluetooth]
        )
        #elseif os(watchOS)
        try session.setCategory(.record, mode: .default)
        #endif
        try session.setActive(true)
    }

    public func deactivateAfterRecording() async throws {
        try session.setActive(false, options: [.notifyOthersOnDeactivation])
    }

    private static func mapRecordPermission(
        _ permission: AVAudioSession.RecordPermission
    ) -> AppleAudioCapturePermission {
        switch permission {
        case .granted:
            return .granted
        case .denied:
            return .denied
        case .undetermined:
            return .notDetermined
        @unknown default:
            return .unknown
        }
    }
}
#endif
