import Foundation

struct WorkoutSession: Codable, Equatable, Identifiable {
    let id: UUID
    var workoutTemplateID: UUID
    var workoutTemplateName: String
    var status: WorkoutSessionStatus
    var startedAt: String
    var completedAt: String?
    var canceledAt: String?
    var createdAt: String
    var updatedAt: String
    var lockVersion: Int
    var exercises: [WorkoutSessionExercise]

    enum CodingKeys: String, CodingKey {
        case id
        case workoutTemplateID = "workout_template_id"
        case workoutTemplateName = "workout_template_name"
        case status
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case canceledAt = "canceled_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lockVersion = "lock_version"
        case exercises
    }
}

struct WorkoutSessionExercise: Codable, Equatable, Identifiable {
    let id: UUID
    var workoutTemplateSlotID: UUID?
    var workoutTemplateExerciseOptionID: UUID?
    var position: Int
    var label: String
    var selectedExerciseID: UUID
    var selectedExercise: WorkoutSessionExerciseSummary
    var restSeconds: Int
    var plannedWorkingLoadValue: Double?
    var progressionIncrement: Double?
    var status: WorkoutSessionExerciseStatus
    var lockVersion: Int
    var createdAt: String
    var updatedAt: String
    var workoutSessionSets: [WorkoutSessionSet]

    enum CodingKeys: String, CodingKey {
        case id
        case workoutTemplateSlotID = "workout_template_slot_id"
        case workoutTemplateExerciseOptionID = "workout_template_exercise_option_id"
        case position
        case label
        case selectedExerciseID = "selected_exercise_id"
        case selectedExercise = "selected_exercise"
        case restSeconds = "rest_seconds"
        case plannedWorkingLoadValue = "planned_working_load_value"
        case progressionIncrement = "progression_increment"
        case status
        case lockVersion = "lock_version"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case workoutSessionSets = "workout_session_sets"
    }
}

extension WorkoutSessionExercise {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        workoutTemplateSlotID = try container.decodeIfPresent(UUID.self, forKey: .workoutTemplateSlotID)
        workoutTemplateExerciseOptionID = try container.decodeIfPresent(
            UUID.self,
            forKey: .workoutTemplateExerciseOptionID
        )
        position = try container.decode(Int.self, forKey: .position)
        label = try container.decode(String.self, forKey: .label)
        selectedExerciseID = try container.decode(UUID.self, forKey: .selectedExerciseID)
        selectedExercise = try container.decode(WorkoutSessionExerciseSummary.self, forKey: .selectedExercise)
        restSeconds = try container.decode(Int.self, forKey: .restSeconds)
        plannedWorkingLoadValue = try container.decodeIfPresent(Double.self, forKey: .plannedWorkingLoadValue)
        progressionIncrement = try container.decodeIfPresent(Double.self, forKey: .progressionIncrement)
        status = try container.decode(WorkoutSessionExerciseStatus.self, forKey: .status)
        lockVersion = try container.decodeIfPresent(Int.self, forKey: .lockVersion) ?? 0
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
        workoutSessionSets = try container.decode([WorkoutSessionSet].self, forKey: .workoutSessionSets)
    }
}

struct WorkoutSessionExerciseSummary: Codable, Equatable {
    let id: UUID
    var name: String
    var loadType: LoadType

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case loadType = "load_type"
    }
}

struct WorkoutSessionSet: Codable, Equatable, Identifiable {
    let id: UUID
    var workoutTemplateSetPrescriptionID: UUID?
    var position: Int
    var setType: SetType
    var targetRepMin: Int
    var targetRepMax: Int
    var loadStrategy: LoadStrategy
    var prescribedLoadValue: Double?
    var plannedLoadValue: Double?
    var actualReps: Int?
    var actualLoadValue: Double?
    var completionState: WorkoutSessionSetCompletionState
    var completedAt: String?
    var lockVersion: Int
    var createdAt: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case workoutTemplateSetPrescriptionID = "workout_template_set_prescription_id"
        case position
        case setType = "set_type"
        case targetRepMin = "target_rep_min"
        case targetRepMax = "target_rep_max"
        case loadStrategy = "load_strategy"
        case prescribedLoadValue = "prescribed_load_value"
        case plannedLoadValue = "planned_load_value"
        case actualReps = "actual_reps"
        case actualLoadValue = "actual_load_value"
        case completionState = "completion_state"
        case completedAt = "completed_at"
        case lockVersion = "lock_version"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum WorkoutSessionStatus: String, Codable {
    case active
    case completed
    case canceled
}

enum WorkoutSessionExerciseStatus: String, Codable {
    case pending
    case completed
    case skipped
}

enum WorkoutSessionSetCompletionState: String, Codable {
    case pending
    case completed
    case attemptedButTargetNotMet = "attempted_but_target_not_met"
    case notPerformed = "not_performed"

    var isPerformed: Bool {
        self == .completed || self == .attemptedButTargetNotMet
    }
}
