import Foundation

struct Activity: Codable, Equatable, Identifiable {
    let id: UUID
    var kind: ActivityKind
    var startedAt: String
    var endedAt: String?
    var notes: String?
    var focusTags: [String]
    var source: ActivitySource
    var createdAt: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case notes
        case focusTags = "focus_tags"
        case source
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum ActivityKind: String, Codable, CaseIterable, Identifiable {
    case restDay = "rest_day"
    case basketball
    case recovery
    case other

    var id: Self {
        self
    }
}

enum ActivitySource: String, Codable {
    case manual
}

struct ActivityCreatePayload: Codable, Equatable {
    var id: UUID
    var kind: ActivityKind
    var startedAt: String
    var endedAt: String?
    var notes: String?
    var focusTags: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case notes
        case focusTags = "focus_tags"
    }
}

struct ActivityPage: Equatable {
    var activities: [Activity]
    var limit: Int
    var offset: Int
    var total: Int

    var nextOffset: Int {
        offset + activities.count
    }

    var hasNextPage: Bool {
        !activities.isEmpty && nextOffset < total
    }
}
