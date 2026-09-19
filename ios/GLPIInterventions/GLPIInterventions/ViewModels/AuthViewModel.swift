import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var connectionMode: ConnectionMode
    @Published private(set) var isAuthenticated = false
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    // Mode "Direct"
    @Published var serverURLText: String = ""
    @Published var appToken: String = ""
    @Published var userToken: String = ""

    // Mode "Fichier partagé"
    @Published var exportFileURLText: String = ""

    @Published private(set) var currentUserName: String?
    /// GLPI numeric user id, only meaningful in `.direct` mode (used to
    /// register this device with the push notification relay).
    @Published private(set) var currentUserId: Int?

    private(set) var repository: TicketsRepository?

    private enum Keys {
        static let mode = "connection.mode"
        static let serverURL = "glpi.serverURL"
        static let appToken = "glpi.appToken"
        static let userToken = "glpi.userToken"
        static let exportURL = "export.fileURL"
    }

    init() {
        connectionMode = UserDefaults.standard.string(forKey: Keys.mode).flatMap(ConnectionMode.init) ?? .direct
        serverURLText = KeychainStore.get(Keys.serverURL) ?? ""
        appToken = KeychainStore.get(Keys.appToken) ?? ""
        userToken = KeychainStore.get(Keys.userToken) ?? ""
        exportFileURLText = KeychainStore.get(Keys.exportURL) ?? ""
    }

    /// Attempts to restore a session from previously saved credentials.
    /// Call once at app launch.
    func restoreSessionIfPossible() async {
        switch connectionMode {
        case .direct:
            guard !serverURLText.isEmpty, !appToken.isEmpty, !userToken.isEmpty else { return }
        case .fileExport:
            guard !exportFileURLText.isEmpty else { return }
        }
        await connect()
    }

    func connect() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        switch connectionMode {
        case .direct:
            await connectDirect()
        case .fileExport:
            await connectFileExport()
        }
    }

    func logout() async {
        if let glpiRepository = repository as? GLPIRepository {
            await glpiRepository.killSession()
        }
        repository = nil
        isAuthenticated = false
        currentUserName = nil
        currentUserId = nil
        KeychainStore.delete(Keys.serverURL)
        KeychainStore.delete(Keys.appToken)
        KeychainStore.delete(Keys.userToken)
        KeychainStore.delete(Keys.exportURL)
        UserDefaults.standard.removeObject(forKey: Keys.mode)
    }

    private func connectDirect() async {
        guard let url = URL(string: serverURLText), url.scheme != nil else {
            errorMessage = "L'URL du serveur GLPI est invalide (ex : https://glpi.exemple.com)."
            return
        }
        guard !appToken.isEmpty, !userToken.isEmpty else {
            errorMessage = "L'App-Token et le User-Token sont obligatoires."
            return
        }

        let config = GLPIConfig(serverURL: url, appToken: appToken, userToken: userToken)
        let client = GLPIAPIClient(config: config)

        do {
            try await client.initSession()
            let session = try await client.getFullSession()
            repository = GLPIRepository(client: client, currentUserId: session.session.userId)
            currentUserName = session.session.userName
            currentUserId = session.session.userId
            isAuthenticated = true

            UserDefaults.standard.set(ConnectionMode.direct.rawValue, forKey: Keys.mode)
            KeychainStore.set(serverURLText, forKey: Keys.serverURL)
            KeychainStore.set(appToken, forKey: Keys.appToken)
            KeychainStore.set(userToken, forKey: Keys.userToken)
        } catch {
            isAuthenticated = false
            repository = nil
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func connectFileExport() async {
        guard let url = URL(string: exportFileURLText), url.scheme != nil else {
            errorMessage = "L'URL du fichier d'export est invalide."
            return
        }

        let fileRepository = FileExportRepository(fileURL: url)
        do {
            _ = try await fileRepository.fetchTicketSummaries(includeClosed: true)
            repository = fileRepository
            currentUserName = nil
            currentUserId = nil
            isAuthenticated = true

            UserDefaults.standard.set(ConnectionMode.fileExport.rawValue, forKey: Keys.mode)
            KeychainStore.set(exportFileURLText, forKey: Keys.exportURL)
        } catch {
            isAuthenticated = false
            repository = nil
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
