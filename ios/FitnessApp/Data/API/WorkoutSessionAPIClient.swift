import Foundation

struct WorkoutSessionAPIClient {
    var baseURL: URL
    var session: URLSession

    static let live = WorkoutSessionAPIClient(
        baseURL: URL(string: "http://localhost:3000")!,
        session: .shared
    )

    func listWorkoutSessions(
        status: WorkoutSessionStatus = .completed,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> WorkoutSessionPage {
        let envelope: WorkoutSessionListEnvelope = try await request(
            path: "/api/v1/workout_sessions",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "status", value: status.rawValue),
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "offset", value: String(offset))
            ]
        )

        return WorkoutSessionPage(
            sessions: envelope.workoutSessions,
            limit: envelope.meta.limit,
            offset: envelope.meta.offset,
            total: envelope.meta.total
        )
    }

    func startWorkoutSession(templateID: UUID, startedAt: String? = nil) async throws -> WorkoutSession {
        let envelope: WorkoutSessionEnvelope = try await request(
            path: "/api/v1/workout_sessions",
            method: "POST",
            body: WorkoutSessionRequestEnvelope(
                workoutSession: WorkoutSessionStartPayload(
                    workoutTemplateID: templateID,
                    startedAt: startedAt
                )
            )
        )

        return envelope.workoutSession
    }

    func createWorkoutSession(payload: WorkoutSessionCreatePayload) async throws -> WorkoutSession {
        let envelope: WorkoutSessionEnvelope = try await request(
            path: "/api/v1/workout_sessions",
            method: "POST",
            body: WorkoutSessionRequestEnvelope(workoutSession: payload)
        )

        return envelope.workoutSession
    }

    func getWorkoutSession(id: UUID) async throws -> WorkoutSession {
        let envelope: WorkoutSessionEnvelope = try await request(
            path: "/api/v1/workout_sessions/\(id.uuidString)",
            method: "GET"
        )

        return envelope.workoutSession
    }

    func updateWorkoutSessionSet(id: UUID, payload: WorkoutSessionSetUpdatePayload) async throws -> WorkoutSessionSet {
        let envelope: WorkoutSessionSetEnvelope = try await request(
            path: "/api/v1/workout_session_sets/\(id.uuidString)",
            method: "PATCH",
            body: WorkoutSessionSetRequestEnvelope(workoutSessionSet: payload)
        )

        return envelope.workoutSessionSet
    }

    func updateWorkoutSessionExercise(
        id: UUID,
        payload: WorkoutSessionExerciseUpdatePayload
    ) async throws -> WorkoutSessionExercise {
        let envelope: WorkoutSessionExerciseEnvelope = try await request(
            path: "/api/v1/workout_session_exercises/\(id.uuidString)",
            method: "PATCH",
            body: WorkoutSessionExerciseRequestEnvelope(workoutSessionExercise: payload)
        )

        return envelope.workoutSessionExercise
    }

    func updateWorkoutSession(id: UUID, payload: WorkoutSessionStatusPayload) async throws -> WorkoutSession {
        let envelope: WorkoutSessionEnvelope = try await request(
            path: "/api/v1/workout_sessions/\(id.uuidString)",
            method: "PATCH",
            body: WorkoutSessionRequestEnvelope(workoutSession: payload)
        )

        return envelope.workoutSession
    }

    private func request<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        body: Body? = Optional<String>.none
    ) async throws -> Response {
        let url = baseURL.appending(path: path)
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw WorkoutSessionAPIError.invalidResponse
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let requestURL = components.url else {
            throw WorkoutSessionAPIError.invalidResponse
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WorkoutSessionAPIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw WorkoutSessionAPIError.requestFailed(statusCode: httpResponse.statusCode)
        }

        return try JSONDecoder().decode(Response.self, from: data)
    }
}

enum WorkoutSessionAPIError: Error, Equatable {
    case invalidResponse
    case requestFailed(statusCode: Int)
}

struct WorkoutSessionPage: Equatable {
    var sessions: [WorkoutSession]
    var limit: Int
    var offset: Int
    var total: Int

    var nextOffset: Int {
        offset + sessions.count
    }

    var hasNextPage: Bool {
        !sessions.isEmpty && nextOffset < total
    }
}

struct WorkoutSessionStartPayload: Codable, Equatable {
    var workoutTemplateID: UUID
    var startedAt: String?

    enum CodingKeys: String, CodingKey {
        case workoutTemplateID = "workout_template_id"
        case startedAt = "started_at"
    }
}

struct WorkoutSessionCreatePayload: Codable, Equatable {
    var id: UUID
    var workoutTemplateID: UUID
    var workoutTemplateName: String
    var startedAt: String
    var exercises: [WorkoutSessionExerciseCreatePayload]

    enum CodingKeys: String, CodingKey {
        case id
        case workoutTemplateID = "workout_template_id"
        case workoutTemplateName = "workout_template_name"
        case startedAt = "started_at"
        case exercises
    }
}

struct WorkoutSessionExerciseCreatePayload: Codable, Equatable {
    var id: UUID
    var workoutTemplateSlotID: UUID?
    var workoutTemplateExerciseOptionID: UUID?
    var selectedExerciseID: UUID
    var position: Int
    var label: String
    var selectedExerciseName: String
    var selectedExerciseLoadType: LoadType
    var restSeconds: Int
    var plannedWorkingLoadValue: Double?
    var progressionIncrement: Double?
    var workoutSessionSets: [WorkoutSessionSetCreatePayload]

    enum CodingKeys: String, CodingKey {
        case id
        case workoutTemplateSlotID = "workout_template_slot_id"
        case workoutTemplateExerciseOptionID = "workout_template_exercise_option_id"
        case selectedExerciseID = "selected_exercise_id"
        case position
        case label
        case selectedExerciseName = "selected_exercise_name"
        case selectedExerciseLoadType = "selected_exercise_load_type"
        case restSeconds = "rest_seconds"
        case plannedWorkingLoadValue = "planned_working_load_value"
        case progressionIncrement = "progression_increment"
        case workoutSessionSets = "workout_session_sets"
    }
}

struct WorkoutSessionSetCreatePayload: Codable, Equatable {
    var id: UUID
    var workoutTemplateSetPrescriptionID: UUID?
    var position: Int
    var setType: SetType
    var targetRepMin: Int
    var targetRepMax: Int
    var loadStrategy: LoadStrategy
    var prescribedLoadValue: Double?
    var plannedLoadValue: Double?

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
    }
}

struct WorkoutSessionSetUpdatePayload: Codable, Equatable {
    var actualReps: Int?
    var actualLoadValue: Double?
    var completionState: WorkoutSessionSetCompletionState
    var completedAt: String?
    var lockVersion: Int

    enum CodingKeys: String, CodingKey {
        case actualReps = "actual_reps"
        case actualLoadValue = "actual_load_value"
        case completionState = "completion_state"
        case completedAt = "completed_at"
        case lockVersion = "lock_version"
    }
}

struct WorkoutSessionExerciseUpdatePayload: Codable, Equatable {
    var workoutTemplateExerciseOptionID: UUID
    var lockVersion: Int

    enum CodingKeys: String, CodingKey {
        case workoutTemplateExerciseOptionID = "workout_template_exercise_option_id"
        case lockVersion = "lock_version"
    }
}

struct WorkoutSessionStatusPayload: Codable, Equatable {
    var status: WorkoutSessionStatus
    var completedAt: String?
    var canceledAt: String? = nil
    var lockVersion: Int

    enum CodingKeys: String, CodingKey {
        case status
        case completedAt = "completed_at"
        case canceledAt = "canceled_at"
        case lockVersion = "lock_version"
    }
}

private struct WorkoutSessionListEnvelope: Decodable {
    var workoutSessions: [WorkoutSession]
    var meta: PaginationMeta

    enum CodingKeys: String, CodingKey {
        case workoutSessions = "workout_sessions"
        case meta
    }
}

private struct PaginationMeta: Decodable {
    var limit: Int
    var offset: Int
    var total: Int
}

private struct WorkoutSessionEnvelope: Decodable {
    var workoutSession: WorkoutSession

    enum CodingKeys: String, CodingKey {
        case workoutSession = "workout_session"
    }
}

private struct WorkoutSessionSetEnvelope: Decodable {
    var workoutSessionSet: WorkoutSessionSet

    enum CodingKeys: String, CodingKey {
        case workoutSessionSet = "workout_session_set"
    }
}

private struct WorkoutSessionRequestEnvelope<Payload: Encodable>: Encodable {
    var workoutSession: Payload

    enum CodingKeys: String, CodingKey {
        case workoutSession = "workout_session"
    }
}

private struct WorkoutSessionSetRequestEnvelope: Encodable {
    var workoutSessionSet: WorkoutSessionSetUpdatePayload

    enum CodingKeys: String, CodingKey {
        case workoutSessionSet = "workout_session_set"
    }
}

private struct WorkoutSessionExerciseRequestEnvelope: Encodable {
    var workoutSessionExercise: WorkoutSessionExerciseUpdatePayload

    enum CodingKeys: String, CodingKey {
        case workoutSessionExercise = "workout_session_exercise"
    }
}

private struct WorkoutSessionExerciseEnvelope: Decodable {
    var workoutSessionExercise: WorkoutSessionExercise

    enum CodingKeys: String, CodingKey {
        case workoutSessionExercise = "workout_session_exercise"
    }
}
