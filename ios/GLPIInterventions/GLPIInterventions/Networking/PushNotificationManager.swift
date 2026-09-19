import Foundation
import UIKit
import UserNotifications

/// Coordinates local opt-in state with APNs registration and with telling
/// the self-hosted push relay backend which device belongs to which GLPI
/// user. See DeviceTokenService for the relay contract.
@MainActor
final class PushNotificationManager: NSObject, ObservableObject {
    @Published private(set) var isEnabled: Bool
    @Published var lastError: String?

    private var pendingGLPIUserId: Int?
    private var lastDeviceTokenHex: String?

    private enum Keys {
        static let enabled = "push.enabled"
    }

    override init() {
        isEnabled = UserDefaults.standard.bool(forKey: Keys.enabled)
        super.init()
    }

    func enable(glpiUserId: Int?) async {
        guard let glpiUserId else {
            lastError = "Connectez-vous d'abord pour activer les notifications."
            return
        }
        do {
            let center = UNUserNotificationCenter.current()
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            guard granted else {
                lastError = "Autorisation de notification refusée dans les réglages iOS."
                return
            }
            pendingGLPIUserId = glpiUserId
            isEnabled = true
            UserDefaults.standard.set(true, forKey: Keys.enabled)
            UIApplication.shared.registerForRemoteNotifications()

            if let token = lastDeviceTokenHex {
                await registerWithRelay(deviceToken: token, glpiUserId: glpiUserId)
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func disable() {
        isEnabled = false
        UserDefaults.standard.set(false, forKey: Keys.enabled)
    }

    /// Called by the AppDelegate once APNs hands us a device token.
    func didReceiveDeviceToken(_ tokenData: Data) {
        let hex = tokenData.map { String(format: "%02x", $0) }.joined()
        lastDeviceTokenHex = hex
        guard isEnabled, let glpiUserId = pendingGLPIUserId else { return }
        Task { await registerWithRelay(deviceToken: hex, glpiUserId: glpiUserId) }
    }

    func didFailToRegister(_ error: Error) {
        lastError = "Échec d'enregistrement APNs : \(error.localizedDescription)"
    }

    private func registerWithRelay(deviceToken: String, glpiUserId: Int) async {
        guard
            let baseURLString = UserDefaults.standard.string(forKey: "relay.baseURL"),
            let baseURL = URL(string: baseURLString),
            !baseURLString.isEmpty
        else {
            lastError = "Renseignez l'URL du relais de notifications dans Réglages."
            return
        }
        let apiKey = UserDefaults.standard.string(forKey: "relay.apiKey") ?? ""
        let relay = DeviceTokenService.RelayConfig(baseURL: baseURL, apiKey: apiKey)
        do {
            try await DeviceTokenService.register(deviceToken: deviceToken, glpiUserId: glpiUserId, relay: relay)
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
