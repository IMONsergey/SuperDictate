import AudioToolbox
import CoreMedia
import Foundation
import SuperDictateCore

enum MemorySystemSampleBufferCopyError: Error, Equatable {
    case invalidSampleBuffer
    case missingFormatDescription
    case unsupportedFormatID(AudioFormatID)
    case unsupportedPCMFlags(UInt32)
    case unsupportedBitsPerChannel(UInt32)
    case invalidSampleRate(Double)
    case invalidChannelCount(Int)
    case emptySampleBuffer
    case invalidPresentationTimestamp
    case audioBufferListQueryFailed(OSStatus)
    case audioBufferListReadFailed(OSStatus)
    case inconsistentAudioBufferList
    case missingAudioData
}

/// Synchronous ScreenCaptureKit callback-bound copy from CMSampleBuffer into the
/// same Sendable PCM value used by the independent microphone source.
///
/// ScreenCaptureKit is configured for 48 kHz stereo, but the actual sample buffer
/// format remains authoritative. This copier validates Linear PCM Float32 and
/// handles both interleaved and non-interleaved layouts instead of assuming one.
enum MemorySystemSampleBufferCopy {
    static func makeBlock(
        from sampleBuffer: CMSampleBuffer,
        sessionStartMilliseconds: Int64
    ) throws -> SuperDictateMemoryPCMBlock {
        guard CMSampleBufferIsValid(sampleBuffer) else {
            throw MemorySystemSampleBufferCopyError.invalidSampleBuffer
        }
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbdPointer = CMAudioFormatDescriptionGetStreamBasicDescription(
                  formatDescription
              ) else {
            throw MemorySystemSampleBufferCopyError.missingFormatDescription
        }

        let asbd = asbdPointer.pointee
        guard asbd.mFormatID == kAudioFormatLinearPCM else {
            throw MemorySystemSampleBufferCopyError.unsupportedFormatID(
                asbd.mFormatID
            )
        }
        guard asbd.mBitsPerChannel == 32 else {
            throw MemorySystemSampleBufferCopyError.unsupportedBitsPerChannel(
                asbd.mBitsPerChannel
            )
        }

        let requiredFlags = AudioFormatFlags(kAudioFormatFlagIsFloat)
        guard asbd.mFormatFlags & requiredFlags == requiredFlags else {
            throw MemorySystemSampleBufferCopyError.unsupportedPCMFlags(
                asbd.mFormatFlags
            )
        }

        let sampleRate = asbd.mSampleRate
        guard sampleRate.isFinite,
              sampleRate > 0,
              abs(sampleRate - sampleRate.rounded()) < 0.000_001 else {
            throw MemorySystemSampleBufferCopyError.invalidSampleRate(sampleRate)
        }

        let channelCount = Int(asbd.mChannelsPerFrame)
        guard channelCount == 1 || channelCount == 2 else {
            throw MemorySystemSampleBufferCopyError.invalidChannelCount(
                channelCount
            )
        }

        let frameCount = Int(CMSampleBufferGetNumSamples(sampleBuffer))
        guard frameCount > 0 else {
            throw MemorySystemSampleBufferCopyError.emptySampleBuffer
        }

        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        guard presentationTime.isValid,
              presentationTime.isNumeric else {
            throw MemorySystemSampleBufferCopyError.invalidPresentationTimestamp
        }

        let channels = try copiedFloatChannels(
            from: sampleBuffer,
            asbd: asbd,
            frameCount: frameCount,
            channelCount: channelCount
        )

        return try SuperDictateMemoryPCMBlock(
            sampleRate: sampleRate,
            channels: channels,
            sessionStartMilliseconds: sessionStartMilliseconds
        )
    }

    private static func copiedFloatChannels(
        from sampleBuffer: CMSampleBuffer,
        asbd: AudioStreamBasicDescription,
        frameCount: Int,
        channelCount: Int
    ) throws -> [[Float]] {
        var requiredBytes = 0
        let queryStatus = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: &requiredBytes,
            bufferListOut: nil,
            bufferListSize: 0,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: UInt32(kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment),
            blockBufferOut: nil
        )
        guard queryStatus == noErr,
              requiredBytes >= MemoryLayout<AudioBufferList>.size else {
            throw MemorySystemSampleBufferCopyError.audioBufferListQueryFailed(
                queryStatus
            )
        }

        let raw = UnsafeMutableRawPointer.allocate(
            byteCount: requiredBytes,
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { raw.deallocate() }
        let audioBufferList = raw.bindMemory(
            to: AudioBufferList.self,
            capacity: 1
        )
        var retainedBlockBuffer: CMBlockBuffer?

        let readStatus = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: audioBufferList,
            bufferListSize: requiredBytes,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: UInt32(kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment),
            blockBufferOut: &retainedBlockBuffer
        )
        guard readStatus == noErr else {
            throw MemorySystemSampleBufferCopyError.audioBufferListReadFailed(
                readStatus
            )
        }

        let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
        let isNonInterleaved = (
            asbd.mFormatFlags & AudioFormatFlags(kAudioFormatFlagIsNonInterleaved)
        ) != 0

        if isNonInterleaved {
            guard buffers.count == channelCount else {
                throw MemorySystemSampleBufferCopyError.inconsistentAudioBufferList
            }
            var result: [[Float]] = []
            result.reserveCapacity(channelCount)
            for channelIndex in 0..<channelCount {
                let audioBuffer = buffers[channelIndex]
                guard let data = audioBuffer.mData else {
                    throw MemorySystemSampleBufferCopyError.missingAudioData
                }
                let expectedBytes = frameCount * MemoryLayout<Float>.size
                guard Int(audioBuffer.mDataByteSize) >= expectedBytes else {
                    throw MemorySystemSampleBufferCopyError.inconsistentAudioBufferList
                }
                let pointer = data.assumingMemoryBound(to: Float.self)
                result.append(
                    Array(
                        UnsafeBufferPointer(
                            start: pointer,
                            count: frameCount
                        )
                    )
                )
            }
            return result
        }

        guard buffers.count == 1,
              let data = buffers[0].mData else {
            throw MemorySystemSampleBufferCopyError.inconsistentAudioBufferList
        }
        let expectedSamples = frameCount * channelCount
        let expectedBytes = expectedSamples * MemoryLayout<Float>.size
        guard Int(buffers[0].mDataByteSize) >= expectedBytes else {
            throw MemorySystemSampleBufferCopyError.inconsistentAudioBufferList
        }

        let interleaved = data.assumingMemoryBound(to: Float.self)
        var result = Array(
            repeating: [Float](),
            count: channelCount
        )
        for channelIndex in 0..<channelCount {
            result[channelIndex].reserveCapacity(frameCount)
        }
        for frameIndex in 0..<frameCount {
            let base = frameIndex * channelCount
            for channelIndex in 0..<channelCount {
                result[channelIndex].append(
                    interleaved[base + channelIndex]
                )
            }
        }
        return result
    }
}
