import SwiftUI
import MSAL

@main
struct EquipmentRequestApp: App {
    @StateObject private var config = AppConfig.shared
    @StateObject private var authService = GraphAuthService.shared

    init() {
        // Tente de configurer MSAL dès le lancement si des identifiants sont déjà enregistrés.
        try? GraphAuthService.shared.configure(with: AppConfig.shared)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(config)
                .environmentObject(authService)
                .onOpenURL { url in
                    // Requis par MSAL pour le retour de connexion via le broker
                    // (app Microsoft Authenticator) ou le navigateur système.
                    _ = MSALPublicClientApplication.handleMSALResponse(
                        url,
                        sourceApplication: nil
                    )
                }
        }
    }
}
