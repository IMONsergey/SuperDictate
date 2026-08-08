import AVFoundation
import CoreMedia
import Darwin
import Foundation

enum MemoryCaptureClockError: Error, Equatable, Sendable {
    case invalidHostTime
    case timeBeforeSessionAnchor
    case invalidSourceClockTime
}

/// One host-clock anchor shared by every source track in a Memory session.
///
/// AVAudioTime host time and CoreMedia host time both use mach_absolute_time on
/// macOS. ScreenCaptureKit PTS values are first converted from the stream's
/// synchronization clock into the host clock. As a result microphone and system
/// audio remain separate source files but their manifest timestamps share one
/// real session timeline.
struct MemoryCaptureClockAnchor: Equatable, Sendable {
    let hostTime: UInt64

    static func now() -> MemoryCaptureClockAnchor {
        MemoryCaptureClockAnchor(hostTime: mach_absolute_time())
    }

    func milliseconds(atHostTime value: UInt64) throws -> Int64 {
        guard value >= hostTime else {
            throw MemoryCaptureClockError.timeBeforeSessionAnchor
        }
        let delta = value - hostTime
        let seconds = AVAudioTime.seconds(forHostTime: delta)
        guard seconds.isFinite, seconds >= 0 else {
            throw MemoryCaptureClockError.invalidHostTime
        }
        return Int64((seconds * 1_000.0).rounded())
    }

    func milliseconds(
        presentationTime: CMTime,
        from sourceClock: CMClock
    ) throws -> Int64 {
        guard presentationTime.isValid,
              presentationTime.isNumeric else {
            throw MemoryCaptureClockError.invalidSourceClockTime
        }
        let hostClock = CMClockGetHostTimeClock()
        let hostTimeValue = CMSyncConvertTime(
            presentationTime,
            from: sourceClock,
            to: hostClock
        )
        guard hostTimeValue.isValid,
              hostTimeValue.isNumeric else {
            throw MemoryCaptureClockError.invalidSourceClockTime
        }
        let hostUnits = CMClockConvertHostTimeToSystemUnits(hostTimeValue)
        return try milliseconds(atHostTime: hostUnits)
    }
}
