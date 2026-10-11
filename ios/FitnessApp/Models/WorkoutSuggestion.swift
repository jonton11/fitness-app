import Foundation

struct WorkoutSuggestion: Codable, Equatable {
    var workoutTemplateID: UUID
    var workoutTemplateName: String
    var focusTags: [String]
    var lastRelevantAt: String?

    enum CodingKeys: String, CodingKey {
        case workoutTemplateID = "workout_template_id"
        case workoutTemplateName = "workout_template_name"
        case focusTags = "focus_tags"
        case lastRelevantAt = "last_relevant_at"
    }
}
