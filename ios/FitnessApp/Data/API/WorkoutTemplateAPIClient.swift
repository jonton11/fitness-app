import Foundation

struct WorkoutTemplateAPIClient {
    var baseURL: URL
    var session: URLSession

    static let live = WorkoutTemplateAPIClient(
        baseURL: URL(string: "http://localhost:3000")!,
        session: .shared
    )

    func listWorkoutTemplates() async throws -> [WorkoutTemplate] {
        let envelope: WorkoutTemplateListEnvelope = try await request(
            path: "/api/v1/workout_templates",
            method: "GET"
        )

        return envelope.workoutTemplates
    }

    func createWorkoutTemplate(_ payload: WorkoutTemplatePayload) async throws -> WorkoutTemplate {
        let envelope: WorkoutTemplateEnvelope = try await request(
            path: "/api/v1/workout_templates",
            method: "POST",
            body: WorkoutTemplateRequestEnvelope(workoutTemplate: payload)
        )

        return envelope.workoutTemplate
    }

    func updateWorkoutTemplate(id: UUID, payload: WorkoutTemplatePayload) async throws -> WorkoutTemplate {
        let envelope: WorkoutTemplateEnvelope = try await request(
            path: "/api/v1/workout_templates/\(id.uuidString)",
            method: "PATCH",
            body: WorkoutTemplateRequestEnvelope(workoutTemplate: payload)
        )

        return envelope.workoutTemplate
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

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw WorkoutTemplateAPIError.requestFailed
        }

        return try JSONDecoder().decode(Response.self, from: data)
    }
}

enum WorkoutTemplateAPIError: Error {
    case requestFailed
}

private struct WorkoutTemplateListEnvelope: Decodable {
    var workoutTemplates: [WorkoutTemplate]

    enum CodingKeys: String, CodingKey {
        case workoutTemplates = "workout_templates"
    }
}

private struct WorkoutTemplateEnvelope: Decodable {
    var workoutTemplate: WorkoutTemplate

    enum CodingKeys: String, CodingKey {
        case workoutTemplate = "workout_template"
    }
}

private struct WorkoutTemplateRequestEnvelope: Encodable {
    var workoutTemplate: WorkoutTemplatePayload

    enum CodingKeys: String, CodingKey {
        case workoutTemplate = "workout_template"
    }
}
