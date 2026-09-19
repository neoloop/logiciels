import Foundation

/// Registers this device's APNs token with the self-hosted push relay
/// backend (see /backend/glpi-push-relay), so it can notify the user when
/// GLPI assigns them a new ticket or changes one's status.
///
/// This is a separate, optional hop: GLPI itself has no way to push to a
/// phone, so a small relay service polls GLPI on the user's behalf and
/// calls APNs. See backend/glpi-push-relay/README.md for why this exists
/// and how to deploy it.
enum DeviceTokenService {
    struct RelayConfig {
        let baseURL: URL
        let apiKey: String
    }

    static func register(deviceToken: String, glpiUserId: Int, relay: RelayConfig) async throws {
        var request = URLRequest(url: relay.baseURL.appendingPathComponent("register"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(relay.apiKey, forHTTPHeaderField: "X-Relay-Api-Key")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "deviceToken": deviceToken,
            "glpiUserId": glpiUserId,
            "platform": "ios"
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "réponse inconnue"
            throw APIError.http(status: (response as? HTTPURLResponse)?.statusCode ?? -1, message: message)
        }
    }
}
