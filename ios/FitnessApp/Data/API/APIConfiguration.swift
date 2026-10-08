import Foundation

struct APIConfiguration: Sendable {
    private let loadCredentials: @Sendable () -> APICredentials?

    static let live = APIConfiguration {
        try? APICredentialsStorage.load()
    }

    init(
        baseURL: URL,
        bearerToken: String? = nil
    ) {
        let credentials = APICredentials(
            serverURL: baseURL,
            token: bearerToken?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        )
        loadCredentials = { credentials }
    }

    init(loadCredentials: @escaping @Sendable () -> APICredentials?) {
        self.loadCredentials = loadCredentials
    }

    func makeRequest(
        path: String,
        queryItems: [URLQueryItem] = []
    ) throws -> URLRequest {
        let credentials = loadCredentials()
        let baseURL = credentials?.serverURL ?? URL(string: "http://localhost:3000")!
        let url = baseURL.appending(path: path)
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw APIConfigurationError.invalidURL
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let requestURL = components.url else {
            throw APIConfigurationError.invalidURL
        }

        var request = URLRequest(url: requestURL)
        if let token = credentials?.token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
}

enum APIConfigurationError: Error {
    case invalidURL
}
