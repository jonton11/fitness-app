import Foundation

@MainActor
final class ConnectionSettingsViewModel: ObservableObject {
    @Published var serverURL = ""
    @Published var apiToken = ""
    @Published private(set) var hasCredentials = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var confirmationMessage: String?

    private let loadCredentials: () throws -> APICredentials?
    private let saveCredentials: (APICredentials) throws -> Void
    private let clearCredentials: () throws -> Void
    private var storedCredentials: APICredentials?

    init(
        loadCredentials: @escaping () throws -> APICredentials? = APICredentialsStorage.load,
        saveCredentials: @escaping (APICredentials) throws -> Void = APICredentialsStorage.save,
        clearCredentials: @escaping () throws -> Void = APICredentialsStorage.clear
    ) {
        self.loadCredentials = loadCredentials
        self.saveCredentials = saveCredentials
        self.clearCredentials = clearCredentials
        load()
    }

    var tokenFieldLabel: String {
        hasCredentials ? "New API token (optional)" : "API token"
    }

    func save() {
        errorMessage = nil
        confirmationMessage = nil

        guard let normalizedURL = normalizedServerURL() else {
            errorMessage = "Enter a valid HTTP or HTTPS server URL."
            return
        }

        let submittedToken = apiToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = submittedToken.isEmpty ? storedCredentials?.token : submittedToken
        guard let token, !token.isEmpty else {
            errorMessage = "Enter an API token."
            return
        }

        let credentials = APICredentials(serverURL: normalizedURL, token: token)
        do {
            try saveCredentials(credentials)
            storedCredentials = credentials
            serverURL = normalizedURL.absoluteString
            apiToken = ""
            hasCredentials = true
            confirmationMessage = "Connection settings saved."
        } catch {
            errorMessage = "Could not save connection settings."
        }
    }

    func clear() {
        errorMessage = nil
        confirmationMessage = nil

        do {
            try clearCredentials()
            storedCredentials = nil
            serverURL = ""
            apiToken = ""
            hasCredentials = false
        } catch {
            errorMessage = "Could not clear connection settings."
        }
    }

    private func load() {
        do {
            storedCredentials = try loadCredentials()
            if let storedCredentials {
                serverURL = storedCredentials.serverURL.absoluteString
                hasCredentials = !storedCredentials.token.isEmpty
            }
        } catch {
            errorMessage = "Could not load connection settings."
        }
    }

    private func normalizedServerURL() -> URL? {
        let value = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              components.host != nil else {
            return nil
        }

        components.scheme = scheme
        components.path = components.path == "/" ? "" : components.path
        return components.url
    }
}
