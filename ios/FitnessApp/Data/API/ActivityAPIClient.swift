import Foundation

struct ActivityAPIClient {
    private var configuration: APIConfiguration
    var session: URLSession

    static let live = ActivityAPIClient(
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

    func listActivities(limit: Int = 50, offset: Int = 0) async throws -> ActivityPage {
        let envelope: ActivityListEnvelope = try await request(
            path: "/api/v1/activities",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "offset", value: String(offset))
            ]
        )

        return ActivityPage(
            activities: envelope.activities,
            limit: envelope.meta.limit,
            offset: envelope.meta.offset,
            total: envelope.meta.total
        )
    }

    func createActivity(payload: ActivityCreatePayload) async throws -> Activity {
        let envelope: ActivityEnvelope = try await request(
            path: "/api/v1/activities",
            method: "POST",
            body: ActivityRequestEnvelope(activity: payload)
        )

        return envelope.activity
    }

    private func request<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        body: Body? = Optional<String>.none
    ) async throws -> Response {
        var request = try configuration.makeRequest(path: path, queryItems: queryItems)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ActivityAPIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ActivityAPIError.requestFailed(statusCode: httpResponse.statusCode)
        }

        return try JSONDecoder().decode(Response.self, from: data)
    }
}

enum ActivityAPIError: Error, Equatable {
    case invalidResponse
    case requestFailed(statusCode: Int)
}

private struct ActivityListEnvelope: Decodable {
    var activities: [Activity]
    var meta: ActivityPaginationMeta
}

private struct ActivityPaginationMeta: Decodable {
    var limit: Int
    var offset: Int
    var total: Int
}

private struct ActivityEnvelope: Decodable {
    var activity: Activity
}

private struct ActivityRequestEnvelope: Encodable {
    var activity: ActivityCreatePayload
}
