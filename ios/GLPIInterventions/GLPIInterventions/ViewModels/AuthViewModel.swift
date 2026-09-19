import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published private(set) var isAuthenticated = false
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    @Published var serverURLText: String = ""
    @Published var appToken: String = ""
    @Published var userToken: String = ""

    @Published private(set) var currentUserId: Int?
    @Published private(set) var currentUserName: String?

    private(set) var client: GLPIAPIClient?

    private enum Keys {
        static let serverURL = "glpi.serverURL"
        static let appToken = "glpi.appToken"
        static let userToken = "glpi.userToken"
    }

    init() {
        serverURLText = KeychainStore.get(Keys.serverURL) ?? ""
        appToken = KeychainStore.get(Keys.appToken) ?? ""
        userToken = KeychainStore.get(Keys.userToken) ?? ""
    }

    /// Attempts to restore a session from previously saved credentials.
    /// Call once at app launch.
    func restoreSessionIfPossible() async {
        guard !serverURLText.isEmpty, !appToken.isEmpty, !userToken.isEmpty else { return }
        await login()
    }

    func login() async {
        errorMessage = nil
        guard let url = URL(string: serverURLText), url.scheme != nil else {
            errorMessage = "L'URL du serveur GLPI est invalide (ex : https://glpi.exemple.com)."
            return
        }
        guard !appToken.isEmpty, !userToken.isEmpty else {
            errorMessage = "L'App-Token et le User-Token sont obligatoires."
            return
        }

        isLoading = true
        defer { isLoading = false }

        let config = GLPIConfig(serverURL: url, appToken: appToken, userToken: userToken)
        let newClient = GLPIAPIClient(config: config)

        do {
            try await newClient.initSession()
            let session = try await newClient.getFullSession()
            client = newClient
            currentUserId = session.session.userId
            currentUserName = session.session.userName
            isAuthenticated = true

            KeychainStore.set(serverURLText, forKey: Keys.serverURL)
            KeychainStore.set(appToken, forKey: Keys.appToken)
            KeychainStore.set(userToken, forKey: Keys.userToken)
        } catch {
            isAuthenticated = false
            client = nil
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func logout() async {
        await client?.killSession()
        client = nil
        isAuthenticated = false
        currentUserId = nil
        currentUserName = nil
        KeychainStore.delete(Keys.serverURL)
        KeychainStore.delete(Keys.appToken)
        KeychainStore.delete(Keys.userToken)
    }
}
