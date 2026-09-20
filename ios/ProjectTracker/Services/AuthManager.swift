import Foundation
import MSAL
import UIKit

enum AuthError: LocalizedError {
    case notSignedIn
    case noToken

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "Vous n'êtes pas connecté à votre compte Microsoft."
        case .noToken: return "Impossible d'obtenir un jeton d'accès."
        }
    }
}

/// Reads clientId / redirectUri from AuthConfig.swift — see docs/SETUP.md to fill those in
/// after creating the Azure AD app registration.
@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var isSignedIn = false
    @Published var accountName: String?
    @Published var lastError: String?

    private let scopes = ["User.Read", "Files.ReadWrite"]
    private var application: MSALPublicClientApplication?
    private var currentAccount: MSALAccount?

    private init() {
        do {
            let authority = try MSALAADAuthority(url: URL(string: "https://login.microsoftonline.com/common")!)
            let config = MSALPublicClientApplicationConfig(
                clientId: AuthConfig.clientId,
                redirectUri: AuthConfig.redirectUri,
                authority: authority
            )
            application = try MSALPublicClientApplication(configuration: config)
            loadExistingAccount()
        } catch {
            lastError = "Erreur d'initialisation MSAL : \(error.localizedDescription)"
        }
    }

    private func loadExistingAccount() {
        guard let application else { return }
        if let account = try? application.allAccounts().first {
            currentAccount = account
            isSignedIn = true
            accountName = account.username
        }
    }

    func handleRedirect(url: URL) {
        MSALPublicClientApplication.handleMSALResponse(url, sourceApplication: nil)
    }

    func signIn() {
        guard let application else { return }
        guard let presenting = UIApplication.topViewController() else { return }
        let webParameters = MSALWebviewParameters(authPresentationViewController: presenting)
        let parameters = MSALInteractiveTokenParameters(scopes: scopes, webviewParameters: webParameters)
        application.acquireToken(with: parameters) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.lastError = error.localizedDescription
                    return
                }
                guard let result else { return }
                self.currentAccount = result.account
                self.isSignedIn = true
                self.accountName = result.account.username
                self.lastError = nil
            }
        }
    }

    func signOut() {
        guard let application, let currentAccount else { return }
        try? application.remove(currentAccount)
        self.currentAccount = nil
        isSignedIn = false
        accountName = nil
    }

    func acquireTokenSilently() async throws -> String {
        guard let application, let currentAccount else {
            throw AuthError.notSignedIn
        }
        let parameters = MSALSilentTokenParameters(scopes: scopes, account: currentAccount)
        return try await withCheckedThrowingContinuation { continuation in
            application.acquireTokenSilent(with: parameters) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let token = result?.accessToken else {
                    continuation.resume(throwing: AuthError.noToken)
                    return
                }
                continuation.resume(returning: token)
            }
        }
    }
}

extension UIApplication {
    static func topViewController(
        _ base: UIViewController? = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.rootViewController
    ) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topViewController(nav.visibleViewController)
        }
        if let tab = base as? UITabBarController, let selected = tab.selectedViewController {
            return topViewController(selected)
        }
        if let presented = base?.presentedViewController {
            return topViewController(presented)
        }
        return base
    }
}
