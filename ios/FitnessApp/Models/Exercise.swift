import Foundation

struct Exercise: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var primaryMuscleGroup: String
    var secondaryMuscleGroups: [String]
    var loadType: LoadType
    var notes: String?
    var externalURL: String?
    var archivedAt: String?
    var createdAt: String
    var updatedAt: String
    var lockVersion: Int

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case primaryMuscleGroup = "primary_muscle_group"
        case secondaryMuscleGroups = "secondary_muscle_groups"
        case loadType = "load_type"
        case notes
        case externalURL = "external_url"
        case archivedAt = "archived_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lockVersion = "lock_version"
    }
}

enum LoadType: String, CaseIterable, Codable, Identifiable {
    case lb
    case kg
    case machineStack = "machine_stack"
    case plateCount = "plate_count"
    case bodyweight
    case bodyweightPlusAdded = "bodyweight_plus_added"
    case assisted
    case none

    var id: String { rawValue }

    var label: String {
        switch self {
        case .lb:
            "Pounds"
        case .kg:
            "Kilograms"
        case .machineStack:
            "Machine stack"
        case .plateCount:
            "Plate count"
        case .bodyweight:
            "Bodyweight"
        case .bodyweightPlusAdded:
            "Bodyweight plus added"
        case .assisted:
            "Assisted"
        case .none:
            "None"
        }
    }
}

struct ExercisePayload: Codable, Equatable {
    var name: String
    var primaryMuscleGroup: String
    var secondaryMuscleGroups: [String]
    var loadType: LoadType
    var notes: String?
    var externalURL: String?
    var lockVersion: Int?

    enum CodingKeys: String, CodingKey {
        case name
        case primaryMuscleGroup = "primary_muscle_group"
        case secondaryMuscleGroups = "secondary_muscle_groups"
        case loadType = "load_type"
        case notes
        case externalURL = "external_url"
        case lockVersion = "lock_version"
    }
}
