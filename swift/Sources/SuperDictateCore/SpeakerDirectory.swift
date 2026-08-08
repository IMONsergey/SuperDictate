import Foundation

public struct SuperDictateSpeakerProfile: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var displayName: String

    public init(id: UUID = UUID(), displayName: String) {
        self.id = id
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.displayName = name.isEmpty ? "Unknown speaker" : name
    }
}

public struct SuperDictateSpeakerAssignment: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var recordingID: UUID
    public var segmentID: UUID
    public var speakerProfileID: UUID

    public init(
        id: UUID = UUID(),
        recordingID: UUID,
        segmentID: UUID,
        speakerProfileID: UUID
    ) {
        self.id = id
        self.recordingID = recordingID
        self.segmentID = segmentID
        self.speakerProfileID = speakerProfileID
    }
}

public enum SuperDictateSpeakerDirectoryError: Error, Equatable, Sendable {
    case unknownSpeaker(UUID)
    case sameSpeakerMerge
}

/// Stable product identity for diarized speakers.
///
/// Evidence segments keep the original diarizer/export label. Assignments map a
/// recording+segment pair to a reusable global speaker profile. Global rename is
/// therefore a profile edit, while merge is an explicit assignment remap.
public struct SuperDictateSpeakerDirectory: Codable, Equatable, Sendable {
    public var profiles: [SuperDictateSpeakerProfile]
    public var assignments: [SuperDictateSpeakerAssignment]

    public init(
        profiles: [SuperDictateSpeakerProfile] = [],
        assignments: [SuperDictateSpeakerAssignment] = []
    ) {
        self.profiles = Self.uniqueProfiles(profiles)
        self.assignments = Self.uniqueAssignments(assignments)
    }

    public func profile(id: UUID) -> SuperDictateSpeakerProfile? {
        profiles.first { $0.id == id }
    }

    public func assignment(recordingID: UUID, segmentID: UUID) -> SuperDictateSpeakerAssignment? {
        assignments.first {
            $0.recordingID == recordingID && $0.segmentID == segmentID
        }
    }

    public func resolvedSpeakerName(
        recordingID: UUID,
        segment: SuperDictateEvidenceSegment
    ) -> String? {
        guard let assignment = assignment(recordingID: recordingID, segmentID: segment.id),
              let profile = profile(id: assignment.speakerProfileID) else {
            return segment.speaker
        }
        return profile.displayName
    }

    public mutating func upsertProfile(_ profile: SuperDictateSpeakerProfile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        } else {
            profiles.append(profile)
        }
    }

    public mutating func renameProfile(id: UUID, to displayName: String) throws {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else {
            throw SuperDictateSpeakerDirectoryError.unknownSpeaker(id)
        }
        profiles[index] = SuperDictateSpeakerProfile(id: id, displayName: displayName)
    }

    public mutating func assign(
        speakerProfileID: UUID,
        recordingID: UUID,
        segmentID: UUID
    ) throws {
        guard profile(id: speakerProfileID) != nil else {
            throw SuperDictateSpeakerDirectoryError.unknownSpeaker(speakerProfileID)
        }
        let assignment = SuperDictateSpeakerAssignment(
            recordingID: recordingID,
            segmentID: segmentID,
            speakerProfileID: speakerProfileID
        )
        if let index = assignments.firstIndex(where: {
            $0.recordingID == recordingID && $0.segmentID == segmentID
        }) {
            assignments[index] = assignment
        } else {
            assignments.append(assignment)
        }
    }

    /// Merge `sourceID` into `targetID`, remapping every segment assignment and
    /// removing only the source profile. Evidence text/timestamps are untouched.
    public mutating func mergeSpeaker(sourceID: UUID, into targetID: UUID) throws {
        guard sourceID != targetID else {
            throw SuperDictateSpeakerDirectoryError.sameSpeakerMerge
        }
        guard profile(id: sourceID) != nil else {
            throw SuperDictateSpeakerDirectoryError.unknownSpeaker(sourceID)
        }
        guard profile(id: targetID) != nil else {
            throw SuperDictateSpeakerDirectoryError.unknownSpeaker(targetID)
        }

        for index in assignments.indices where assignments[index].speakerProfileID == sourceID {
            assignments[index].speakerProfileID = targetID
        }
        profiles.removeAll { $0.id == sourceID }
    }

    public mutating func removeAssignments(recordingID: UUID) {
        assignments.removeAll { $0.recordingID == recordingID }
    }

    private static func uniqueProfiles(
        _ source: [SuperDictateSpeakerProfile]
    ) -> [SuperDictateSpeakerProfile] {
        var order: [UUID] = []
        var latest: [UUID: SuperDictateSpeakerProfile] = [:]
        for profile in source {
            if latest[profile.id] == nil { order.append(profile.id) }
            latest[profile.id] = profile
        }
        return order.compactMap { latest[$0] }
    }

    private static func uniqueAssignments(
        _ source: [SuperDictateSpeakerAssignment]
    ) -> [SuperDictateSpeakerAssignment] {
        struct Key: Hashable {
            let recordingID: UUID
            let segmentID: UUID
        }
        var order: [Key] = []
        var latest: [Key: SuperDictateSpeakerAssignment] = [:]
        for assignment in source {
            let key = Key(
                recordingID: assignment.recordingID,
                segmentID: assignment.segmentID
            )
            if latest[key] == nil { order.append(key) }
            latest[key] = assignment
        }
        return order.compactMap { latest[$0] }
    }
}
