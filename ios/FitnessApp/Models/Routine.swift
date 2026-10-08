import Foundation

struct Routine: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var notes: String?
    var archivedAt: String?
    var items: [RoutineItem]
    var createdAt: String
    var updatedAt: String
    var lockVersion: Int

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case notes
        case archivedAt = "archived_at"
        case items
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lockVersion = "lock_version"
    }
}

struct RoutineItem: Codable, Equatable, Identifiable {
    let id: UUID
    var position: Int
    var exerciseID: UUID
    var exercise: Exercise
    var targetMode: RoutineTargetMode
    var sets: Int?
    var targetReps: Int?
    var targetDurationSeconds: Int?
    var notesOverride: String?
    var createdAt: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case position
        case exerciseID = "exercise_id"
        case exercise
        case targetMode = "target_mode"
        case sets
        case targetReps = "target_reps"
        case targetDurationSeconds = "target_duration_seconds"
        case notesOverride = "notes_override"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum RoutineTargetMode: String, Codable {
    case completionOnly = "completion_only"
    case reps
    case duration
    case loadOptional = "load_optional"
}

struct RoutineSession: Codable, Equatable, Identifiable {
    let id: UUID
    var routineID: UUID?
    var routineName: String
    var status: RoutineSessionStatus
    var startedAt: String
    var completedAt: String?
    var items: [RoutineSessionItem]
    var createdAt: String
    var updatedAt: String
    var lockVersion: Int

    enum CodingKeys: String, CodingKey {
        case id
        case routineID = "routine_id"
        case routineName = "routine_name"
        case status
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case items
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lockVersion = "lock_version"
    }
}

struct RoutineSessionItem: Codable, Equatable, Identifiable {
    let id: UUID
    var routineItemID: UUID?
    var exerciseID: UUID?
    var position: Int
    var exerciseName: String
    var targetMode: RoutineTargetMode
    var sets: Int?
    var targetReps: Int?
    var targetDurationSeconds: Int?
    var notes: String?
    var completedAt: String?
    var lockVersion: Int

    var isCompleted: Bool {
        completedAt != nil
    }

    enum CodingKeys: String, CodingKey {
        case id
        case routineItemID = "routine_item_id"
        case exerciseID = "exercise_id"
        case position
        case exerciseName = "exercise_name"
        case targetMode = "target_mode"
        case sets
        case targetReps = "target_reps"
        case targetDurationSeconds = "target_duration_seconds"
        case notes
        case completedAt = "completed_at"
        case lockVersion = "lock_version"
    }
}

enum RoutineSessionStatus: String, Codable {
    case active
    case completed
}
