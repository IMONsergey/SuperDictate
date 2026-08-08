import AVFoundation
import Foundation
import SuperDictateCore

enum MemoryPCMBufferCopyError: Error, Equatable {
    case unsupportedCommonFormat
    case interleavedInput
    case invalidChannelCount(Int)
    case emptyBuffer
    case missingChannelData
}

/// Synchronous callback-bound copy from AVFoundation into a Sendable Memory PCM
/// value. The AVAudioPCMBuffer never escapes the source callback/queue.
enum MemoryPCMBufferCopy {
    static func makeBlock(
        from buffer: AVAudioPCMBuffer,
        sessionStartMilliseconds: Int64
    ) throws -> SuperDictateMemoryPCMBlock {
        guard buffer.format.commonFormat == .pcmFormatFloat32 else {
            throw MemoryPCMBufferCopyError.unsupportedCommonFormat
        }
        guard !buffer.format.isInterleaved else {
            throw MemoryPCMBufferCopyError.interleavedInput
        }

        let channelCount = Int(buffer.format.channelCount)
        guard channelCount == 1 || channelCount == 2 else {
            throw MemoryPCMBufferCopyError.invalidChannelCount(channelCount)
        }

        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else {
            throw MemoryPCMBufferCopyError.emptyBuffer
        }
        guard let sourceChannels = buffer.floatChannelData else {
            throw MemoryPCMBufferCopyError.missingChannelData
        }

        var channels: [[Float]] = []
        channels.reserveCapacity(channelCount)
        for channelIndex in 0..<channelCount {
            let pointer = sourceChannels[channelIndex]
            channels.append(
                Array(UnsafeBufferPointer(start: pointer, count: frameCount))
            )
        }

        return try SuperDictateMemoryPCMBlock(
            sampleRate: buffer.format.sampleRate,
            channels: channels,
            sessionStartMilliseconds: sessionStartMilliseconds
        )
    }
}
