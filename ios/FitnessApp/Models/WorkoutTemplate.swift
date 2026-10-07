import Foundation

struct WorkoutTemplate: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var notes: String?
    var archivedAt: String?
    var createdAt: String
    var updatedAt: String
    var lockVersion: Int
    var slots: [WorkoutTemplateSlot]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case notes
        case archivedAt = "archived_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lockVersion = "lock_version"
        case slots
    }
}

struct WorkoutTemplateSlot: Codable, Equatable, Identifiable {
    let id: UUID
    var position: Int
    var label: String
    var defaultExerciseID: UUID
    var defaultExercise: TemplateExerciseSummary
    var restSeconds: Int
    var createdAt: String
    var updatedAt: String
    var lockVersion: Int
    var exerciseOptions: [WorkoutTemplateExerciseOption]
    var setPrescriptions: [WorkoutTemplateSetPrescription]

    enum CodingKeys: String, CodingKey {
        case id
        case position
        case label
        case defaultExerciseID = "default_exercise_id"
        case defaultExercise = "default_exercise"
        case restSeconds = "rest_seconds"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lockVersion = "lock_version"
        case exerciseOptions = "exercise_options"
        case setPrescriptions = "set_prescriptions"
    }
}

struct TemplateExerciseSummary: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var primaryMuscleGroup: String
    var loadType: LoadType
    var archivedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case primaryMuscleGroup = "primary_muscle_group"
        case loadType = "load_type"
        case archivedAt = "archived_at"
    }
}

struct WorkoutTemplateExerciseOption: Codable, Equatable, Identifiable {
    let id: UUID
    var position: Int
    var exerciseID: UUID
    var exercise: TemplateExerciseSummary
    var isDefault: Bool
    var startingLoadValue: Double?
    var nextLoadValue: Double?
    var calculatedNextLoadValue: Double?
    var progressionIncrement: Double?
    var createdAt: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case position
        case exerciseID = "exercise_id"
        case exercise
        case isDefault = "is_default"
        case startingLoadValue = "starting_load_value"
        case nextLoadValue = "next_load_value"
        case calculatedNextLoadValue = "calculated_next_load_value"
        case progressionIncrement = "progression_increment"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct WorkoutTemplateSetPrescription: Codable, Equatable, Identifiable {
    let id: UUID
    var position: Int
    var setType: SetType
    var repMin: Int
    var repMax: Int
    var loadStrategy: LoadStrategy
    var loadValue: Double?
    var createdAt: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case position
        case setType = "set_type"
        case repMin = "rep_min"
        case repMax = "rep_max"
        case loadStrategy = "load_strategy"
        case loadValue = "load_value"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum SetType: String, CaseIterable, Codable, Identifiable {
    case warmup
    case working

    var id: String { rawValue }

    var label: String {
        switch self {
        case .warmup:
            "Warm-up"
        case .working:
            "Working"
        }
    }
}

enum LoadStrategy: String, CaseIterable, Codable, Identifiable {
    case workingLoad = "working_load"
    case percentageOfWorkingLoad = "percentage_of_working_load"
    case explicit
    case bodyweight
    case none

    var id: String { rawValue }

    var label: String {
        switch self {
        case .workingLoad:
            "Working load"
        case .percentageOfWorkingLoad:
            "% of working load"
        case .explicit:
            "Explicit"
        case .bodyweight:
            "Bodyweight"
        case .none:
            "None"
        }
    }
}

struct WorkoutTemplatePayload: Codable, Equatable {
    var name: String
    var notes: String?
    var archivedAt: String?
    var lockVersion: Int?
    var slots: [WorkoutTemplateSlotPayload]

    enum CodingKeys: String, CodingKey {
        case name
        case notes
        case archivedAt = "archived_at"
        case lockVersion = "lock_version"
        case slots
    }
}

struct WorkoutTemplateSlotPayload: Codable, Equatable {
    var id: UUID?
    var position: Int
    var label: String
    var defaultExerciseID: UUID
    var restSeconds: Int
    var lockVersion: Int?
    var exerciseOptions: [WorkoutTemplateExerciseOptionPayload]
    var setPrescriptions: [WorkoutTemplateSetPrescriptionPayload]

    enum CodingKeys: String, CodingKey {
        case id
        case position
        case label
        case defaultExerciseID = "default_exercise_id"
        case restSeconds = "rest_seconds"
        case lockVersion = "lock_version"
        case exerciseOptions = "exercise_options"
        case setPrescriptions = "set_prescriptions"
    }
}

struct WorkoutTemplateExerciseOptionPayload: Codable, Equatable {
    var position: Int
    var exerciseID: UUID
    var startingLoadValue: Double?
    var nextLoadValue: Double?
    var progressionIncrement: Double?

    enum CodingKeys: String, CodingKey {
        case position
        case exerciseID = "exercise_id"
        case startingLoadValue = "starting_load_value"
        case nextLoadValue = "next_load_value"
        case progressionIncrement = "progression_increment"
    }
}

struct WorkoutTemplateSetPrescriptionPayload: Codable, Equatable {
    var position: Int
    var setType: SetType
    var repMin: Int
    var repMax: Int
    var loadStrategy: LoadStrategy
    var loadValue: Double?

    enum CodingKeys: String, CodingKey {
        case position
        case setType = "set_type"
        case repMin = "rep_min"
        case repMax = "rep_max"
        case loadStrategy = "load_strategy"
        case loadValue = "load_value"
    }
}
