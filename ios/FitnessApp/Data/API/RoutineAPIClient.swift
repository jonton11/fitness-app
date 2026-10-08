import Foundation

struct RoutineAPIClient {
    private var configuration: APIConfiguration
    var session: URLSession

    static let live = RoutineAPIClient(
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

    func listRoutines() async throws -> [Routine] {
        let envelope: RoutineListEnvelope = try await request(
            path: "/api/v1/routines",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "status", value: "active"),
                URLQueryItem(name: "limit", value: "100")
            ]
        )

        return envelope.routines
    }

    func listRoutineSessions(
        status: RoutineSessionStatus,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> RoutineSessionPage {
        let envelope: RoutineSessionListEnvelope = try await request(
            path: "/api/v1/routine_sessions",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "status", value: status.rawValue),
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "offset", value: String(offset))
            ]
        )

        return RoutineSessionPage(
            sessions: envelope.routineSessions,
            limit: envelope.meta.limit,
            offset: envelope.meta.offset,
            total: envelope.meta.total
        )
    }

    func startRoutineSession(payload: RoutineSessionStartPayload) async throws -> RoutineSession {
        let envelope: RoutineSessionEnvelope = try await request(
            path: "/api/v1/routine_sessions",
            method: "POST",
            body: RoutineSessionRequestEnvelope(routineSession: payload)
        )

        return envelope.routineSession
    }

    func updateRoutineSessionItem(
        id: UUID,
        payload: RoutineSessionItemUpdatePayload
    ) async throws -> RoutineSessionItem {
        let envelope: RoutineSessionItemEnvelope = try await request(
            path: "/api/v1/routine_session_items/\(id.uuidString)",
            method: "PATCH",
            body: RoutineSessionItemRequestEnvelope(routineSessionItem: payload)
        )

        return envelope.routineSessionItem
    }

    func completeRoutineSession(
        id: UUID,
        payload: RoutineSessionCompletionPayload
    ) async throws -> RoutineSession {
        let envelope: RoutineSessionEnvelope = try await request(
            path: "/api/v1/routine_sessions/\(id.uuidString)",
            method: "PATCH",
            body: RoutineSessionRequestEnvelope(routineSession: payload)
        )

        return envelope.routineSession
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
            throw RoutineAPIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw RoutineAPIError.requestFailed(statusCode: httpResponse.statusCode)
        }

        return try JSONDecoder().decode(Response.self, from: data)
    }
}

enum RoutineAPIError: Error, Equatable {
    case invalidResponse
    case requestFailed(statusCode: Int)
}

struct RoutineSessionPage: Equatable {
    var sessions: [RoutineSession]
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

struct RoutineSessionStartPayload: Codable, Equatable {
    var id: UUID
    var routineID: UUID
    var startedAt: String
    var items: [RoutineSessionItemStartPayload]

    enum CodingKeys: String, CodingKey {
        case id
        case routineID = "routine_id"
        case startedAt = "started_at"
        case items
    }
}

struct RoutineSessionItemStartPayload: Codable, Equatable {
    var id: UUID
    var routineItemID: UUID

    enum CodingKeys: String, CodingKey {
        case id
        case routineItemID = "routine_item_id"
    }
}

struct RoutineSessionItemUpdatePayload: Codable, Equatable {
    var completed: Bool
    var completedAt: String?
    var lockVersion: Int

    enum CodingKeys: String, CodingKey {
        case completed
        case completedAt = "completed_at"
        case lockVersion = "lock_version"
    }
}

struct RoutineSessionCompletionPayload: Codable, Equatable {
    var status: RoutineSessionStatus
    var completedAt: String
    var lockVersion: Int

    enum CodingKeys: String, CodingKey {
        case status
        case completedAt = "completed_at"
        case lockVersion = "lock_version"
    }
}

private struct RoutineListEnvelope: Decodable {
    var routines: [Routine]
}

private struct RoutineSessionListEnvelope: Decodable {
    var routineSessions: [RoutineSession]
    var meta: RoutinePaginationMeta

    enum CodingKeys: String, CodingKey {
        case routineSessions = "routine_sessions"
        case meta
    }
}

private struct RoutinePaginationMeta: Decodable {
    var limit: Int
    var offset: Int
    var total: Int
}

private struct RoutineSessionEnvelope: Decodable {
    var routineSession: RoutineSession

    enum CodingKeys: String, CodingKey {
        case routineSession = "routine_session"
    }
}

private struct RoutineSessionItemEnvelope: Decodable {
    var routineSessionItem: RoutineSessionItem

    enum CodingKeys: String, CodingKey {
        case routineSessionItem = "routine_session_item"
    }
}

private struct RoutineSessionRequestEnvelope<Payload: Encodable>: Encodable {
    var routineSession: Payload

    enum CodingKeys: String, CodingKey {
        case routineSession = "routine_session"
    }
}

private struct RoutineSessionItemRequestEnvelope: Encodable {
    var routineSessionItem: RoutineSessionItemUpdatePayload

    enum CodingKeys: String, CodingKey {
        case routineSessionItem = "routine_session_item"
    }
}
