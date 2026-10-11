import Foundation

enum HealthMetricKind: String, Codable, CaseIterable, Sendable {
    case bodyWeight = "body_weight"
    case bodyFatPercentage = "body_fat_percentage"
    case steps
    case activeEnergy = "active_energy"
    case sleepDuration = "sleep_duration"
    case restingHeartRate = "resting_heart_rate"

    var unit: String {
        switch self {
        case .bodyWeight:
            "kg"
        case .bodyFatPercentage:
            "percent"
        case .steps:
            "count"
        case .activeEnergy:
            "kcal"
        case .sleepDuration:
            "minutes"
        case .restingHeartRate:
            "bpm"
        }
    }
}

struct HealthMetricUpload: Codable, Equatable, Sendable {
    var id: UUID
    var kind: HealthMetricKind
    var value: Double
    var unit: String
    var startedAt: String
    var endedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case value
        case unit
        case startedAt = "started_at"
        case endedAt = "ended_at"
    }
}

struct HealthMetric: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var kind: HealthMetricKind
    var value: Double
    var unit: String
    var startedAt: String
    var endedAt: String
    var source: String
    var createdAt: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case value
        case unit
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case source
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct HealthMetricIngestionResult: Equatable, Sendable {
    var metrics: [HealthMetric]
    var createdCount: Int
    var replayedCount: Int
    var deletedCount: Int
}
