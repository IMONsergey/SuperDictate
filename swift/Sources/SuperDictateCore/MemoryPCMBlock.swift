import Foundation

public enum SuperDictateMemoryPCMBlockError: Error, Equatable, Sendable {
    case invalidSampleRate(Double)
    case invalidChannelCount(Int)
    case empty
    case inconsistentFrameCount
    case invalidStartMilliseconds(Int64)
    case nonFiniteSample
}

/// Sendable copy of one capture callback's PCM payload.
///
/// AVAudioPCMBuffer is intentionally not allowed to cross into the Memory writer
/// actor under Swift 6 strict concurrency. Mic/ScreenCaptureKit adapters copy the
/// callback into this value on their source callback, then hand plain Float arrays
/// to the serialized writer. Source timing stays explicit instead of being
/// reconstructed from wall-clock time later.
public struct SuperDictateMemoryPCMBlock: Equatable, Sendable {
    public let sampleRate: Double
    public let channels: [[Float]]
    public let sessionStartMilliseconds: Int64

    public init(
        sampleRate: Double,
        channels: [[Float]],
        sessionStartMilliseconds: Int64
    ) throws {
        guard sampleRate.isFinite, sampleRate > 0 else {
            throw SuperDictateMemoryPCMBlockError.invalidSampleRate(sampleRate)
        }
        guard channels.count == 1 || channels.count == 2 else {
            throw SuperDictateMemoryPCMBlockError.invalidChannelCount(channels.count)
        }
        guard sessionStartMilliseconds >= 0 else {
            throw SuperDictateMemoryPCMBlockError.invalidStartMilliseconds(
                sessionStartMilliseconds
            )
        }
        guard let frameCount = channels.first?.count,
              frameCount > 0 else {
            throw SuperDictateMemoryPCMBlockError.empty
        }
        guard channels.allSatisfy({ $0.count == frameCount }) else {
            throw SuperDictateMemoryPCMBlockError.inconsistentFrameCount
        }
        guard channels.allSatisfy({ channel in
            channel.allSatisfy(\.isFinite)
        }) else {
            throw SuperDictateMemoryPCMBlockError.nonFiniteSample
        }

        self.sampleRate = sampleRate
        self.channels = channels
        self.sessionStartMilliseconds = sessionStartMilliseconds
    }

    public var channelCount: Int { channels.count }
    public var frameCount: Int { channels[0].count }

    public var durationMilliseconds: Int64 {
        Int64(
            (Double(frameCount) / sampleRate * 1_000.0)
                .rounded()
        )
    }

    public var sessionEndMilliseconds: Int64 {
        sessionStartMilliseconds + durationMilliseconds
    }
}
