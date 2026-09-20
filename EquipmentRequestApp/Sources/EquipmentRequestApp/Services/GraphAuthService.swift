import Foundation
import MSAL
import UIKit

enum GraphAuthError: LocalizedError {
    case notConfigured
    case noPresentingViewController
    case noAccount
    case noAccessToken

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "L'application n'est pas configurée : renseignez le Client ID et le Tenant ID dans Réglages."
        case .noPresentingViewController:
            return "Impossible d'afficher l'écran de connexion Microsoft."
        case .noAccount:
            return "Aucun compte Microsoft connecté."
        case .noAccessToken:
            return "Impossible d'obtenir un jeton d'accès Microsoft Graph."
        }
    }
}

/// Gère la connexion à un compte Microsoft (Azure AD) et l'obtention de jetons
/// d'accès Microsoft Graph, nécessaires pour lire/écrire le fichier JSON des
/// demandes sur OneDrive/SharePoint depuis l'app.
@MainActor
final class GraphAuthService: ObservableObject {
    static let shared = GraphAuthService()

    @Published var isSignedIn = false
    @Published var accountDisplayName: String?

    private var application: MSALPublicClientApplication?
    private var currentAccount: MSALAccount?

    private init() {}

    /// (Re)crée le client MSAL à partir de la configuration courante.
    /// À appeler après toute modification du Client ID / Tenant ID dans Réglages.
    func configure(with config: AppConfig) throws {
        guard !config.clientId.isEmpty, !config.tenantId.isEmpty,
              config.clientId != "REMPLACER-PAR-VOTRE-CLIENT-ID" else {
            throw GraphAuthError.notConfigured
        }
        let trimmedTenantId = config.tenantId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let encodedTenantId = trimmedTenantId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
            let authorityURL = URL(string: "https://login.microsoftonline.com/\(encodedTenantId)")
        else {
            throw GraphAuthError.notConfigured
        }
        let authority = try MSALAADAuthority(url: authorityURL)
        let pcaConfig = MSALPublicClientApplicationConfig(
            clientId: config.clientId,
            redirectUri: config.redirectUri,
            authority: authority
        )
        application = try MSALPublicClientApplication(configuration: pcaConfig)
        try loadCachedAccount()
    }

    private func loadCachedAccount() throws {
        guard let application else { return }
        let accounts = try application.allAccounts()
        currentAccount = accounts.first
        isSignedIn = currentAccount != nil
        accountDisplayName = currentAccount?.username
    }

    func signOut() throws {
        guard let application, let currentAccount else { return }
        try application.remove(currentAccount)
        self.currentAccount = nil
        isSignedIn = false
        accountDisplayName = nil
    }

    /// Retourne un jeton d'accès Graph valide, en réutilisant la session existante
    /// si possible, sinon en déclenchant une connexion interactive.
    func acquireToken(scopes: [String]) async throws -> String {
        guard let application else { throw GraphAuthError.notConfigured }

        if let currentAccount {
            do {
                return try await acquireTokenSilently(application: application, account: currentAccount, scopes: scopes)
            } catch {
                return try await acquireTokenInteractively(application: application, scopes: scopes)
            }
        }
        return try await acquireTokenInteractively(application: application, scopes: scopes)
    }

    private func acquireTokenSilently(
        application: MSALPublicClientApplication,
        account: MSALAccount,
        scopes: [String]
    ) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let params = MSALSilentTokenParameters(scopes: scopes, account: account)
            application.acquireTokenSilent(with: params) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let token = result?.accessToken else {
                    continuation.resume(throwing: GraphAuthError.noAccessToken)
                    return
                }
                continuation.resume(returning: token)
            }
        }
    }

    private func acquireTokenInteractively(
        application: MSALPublicClientApplication,
        scopes: [String]
    ) async throws -> String {
        guard let presentingViewController = Self.topViewController() else {
            throw GraphAuthError.noPresentingViewController
        }
        return try await withCheckedThrowingContinuation { continuation in
            let webParameters = MSALWebviewParameters(authPresentationViewController: presentingViewController)
            let params = MSALInteractiveTokenParameters(scopes: scopes, webviewParameters: webParameters)
            application.acquireToken(with: params) { [weak self] result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let result else {
                    continuation.resume(throwing: GraphAuthError.noAccessToken)
                    return
                }
                Task { @MainActor in
                    self?.currentAccount = result.account
                    self?.isSignedIn = true
                    self?.accountDisplayName = result.account.username
                }
                continuation.resume(returning: result.accessToken)
            }
        }
    }

    @MainActor
    private static func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
            let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return nil }

        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}
