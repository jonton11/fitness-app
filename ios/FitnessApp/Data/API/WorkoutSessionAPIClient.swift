import Foundation

struct WorkoutSessionAPIClient {
    var baseURL: URL
    var session: URLSession

    static let live = WorkoutSessionAPIClient(
        baseURL: URL(string: "http://localhost:3000")!,
        session: .shared
    )

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

    private func request<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        body: Body? = Optional<String>.none
    ) async throws -> Response {
        var request = URLRequest(url: baseURL.appending(path: path))
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

struct WorkoutSessionStartPayload: Codable, Equatable {
    var workoutTemplateID: UUID
    var startedAt: String?

    enum CodingKeys: String, CodingKey {
        case workoutTemplateID = "workout_template_id"
        case startedAt = "started_at"
    }
}

struct WorkoutSessionSetUpdatePayload: Codable, Equatable {
    var actualReps: Int
    var actualLoadValue: Double?
    var completionState: WorkoutSessionSetCompletionState
    var completedAt: String
    var lockVersion: Int

    enum CodingKeys: String, CodingKey {
        case actualReps = "actual_reps"
        case actualLoadValue = "actual_load_value"
        case completionState = "completion_state"
        case completedAt = "completed_at"
        case lockVersion = "lock_version"
    }
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

private struct WorkoutSessionRequestEnvelope: Encodable {
    var workoutSession: WorkoutSessionStartPayload

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
