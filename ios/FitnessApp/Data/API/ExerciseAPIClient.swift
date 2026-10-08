import Foundation

struct ExerciseAPIClient {
    private var configuration: APIConfiguration
    var session: URLSession

    static let live = ExerciseAPIClient(
        configuration: .live,
        session: .shared
    )

    init(baseURL: URL, session: URLSession, bearerToken: String? = nil) {
        configuration = APIConfiguration(baseURL: baseURL, bearerToken: bearerToken)
        self.session = session
    }

    init(configuration: APIConfiguration, session: URLSession) {
        self.configuration = configuration
        self.session = session
    }

    func listExercises() async throws -> [Exercise] {
        let envelope: ExerciseListEnvelope = try await request(
            path: "/api/v1/exercises",
            method: "GET"
        )

        return envelope.exercises
    }

    func createExercise(_ payload: ExercisePayload) async throws -> Exercise {
        let envelope: ExerciseEnvelope = try await request(
            path: "/api/v1/exercises",
            method: "POST",
            body: ExerciseRequestEnvelope(exercise: payload)
        )

        return envelope.exercise
    }

    func updateExercise(id: UUID, payload: ExercisePayload) async throws -> Exercise {
        let envelope: ExerciseEnvelope = try await request(
            path: "/api/v1/exercises/\(id.uuidString)",
            method: "PATCH",
            body: ExerciseRequestEnvelope(exercise: payload)
        )

        return envelope.exercise
    }

    private func request<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        body: Body? = Optional<String>.none
    ) async throws -> Response {
        var request = try configuration.makeRequest(path: path)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw ExerciseAPIError.requestFailed
        }

        return try JSONDecoder().decode(Response.self, from: data)
    }
}

enum ExerciseAPIError: Error {
    case requestFailed
}

private struct ExerciseListEnvelope: Decodable {
    var exercises: [Exercise]
}

private struct ExerciseEnvelope: Decodable {
    var exercise: Exercise
}

private struct ExerciseRequestEnvelope: Encodable {
    var exercise: ExercisePayload
}
