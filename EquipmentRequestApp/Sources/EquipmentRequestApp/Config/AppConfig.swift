import Foundation

/// Configuration de l'application, modifiable depuis l'écran Réglages sans recompiler.
/// Les valeurs par défaut ci-dessous sont des exemples à remplacer lors du premier lancement.
final class AppConfig: ObservableObject {
    static let shared = AppConfig()

    private enum Keys {
        static let clientId = "config.clientId"
        static let tenantId = "config.tenantId"
        static let driveBasePath = "config.driveBasePath"
        static let jsonFilePath = "config.jsonFilePath"
        static let validatorEmail = "config.validatorEmail"
        static let validatorName = "config.validatorName"
    }

    /// Application (client) ID de l'inscription Azure AD. Voir README pour la procédure.
    @Published var clientId: String {
        didSet { UserDefaults.standard.set(clientId, forKey: Keys.clientId) }
    }

    /// Directory (tenant) ID Azure AD (ou "organizations" pour multi-tenant).
    @Published var tenantId: String {
        didSet { UserDefaults.standard.set(tenantId, forKey: Keys.tenantId) }
    }

    /// Base du chemin Graph vers le lecteur : "/me/drive" pour OneDrive de l'utilisateur connecté,
    /// ou "/sites/{site-id}/drive" pour un site SharePoint. Voir README.
    @Published var driveBasePath: String {
        didSet { UserDefaults.standard.set(driveBasePath, forKey: Keys.driveBasePath) }
    }

    /// Chemin du fichier .json dans le lecteur, ex: "Suivi_Demandes_Materiel_SIS2B.json".
    /// C'est le même fichier que celui lu/écrit par les pages web.
    @Published var jsonFilePath: String {
        didSet { UserDefaults.standard.set(jsonFilePath, forKey: Keys.jsonFilePath) }
    }

    /// Email du valideur (vous) : mis en copie du mail envoyé et destinataire du retour signé.
    @Published var validatorEmail: String {
        didSet { UserDefaults.standard.set(validatorEmail, forKey: Keys.validatorEmail) }
    }

    @Published var validatorName: String {
        didSet { UserDefaults.standard.set(validatorName, forKey: Keys.validatorName) }
    }

    /// URI de redirection MSAL : doit correspondre exactement à celle déclarée dans Azure AD
    /// et à l'URL scheme du Info.plist : msauth.<bundle-id>://auth
    var redirectUri: String {
        "msauth.\(Bundle.main.bundleIdentifier ?? "com.example.EquipmentRequestApp")://auth"
    }

    /// Scopes Microsoft Graph nécessaires pour lire/écrire le fichier JSON sur OneDrive/SharePoint.
    let graphScopes = ["Files.ReadWrite", "Sites.ReadWrite.All"]

    var isConfigured: Bool {
        !clientId.isEmpty && !tenantId.isEmpty && !jsonFilePath.isEmpty
            && clientId != "REMPLACER-PAR-VOTRE-CLIENT-ID"
    }

    private init() {
        let defaults = UserDefaults.standard
        clientId = defaults.string(forKey: Keys.clientId) ?? "REMPLACER-PAR-VOTRE-CLIENT-ID"
        tenantId = defaults.string(forKey: Keys.tenantId) ?? "REMPLACER-PAR-VOTRE-TENANT-ID"
        driveBasePath = defaults.string(forKey: Keys.driveBasePath) ?? "/me/drive"
        jsonFilePath = defaults.string(forKey: Keys.jsonFilePath) ?? "Suivi_Demandes_Materiel_SIS2B.json"
        validatorEmail = defaults.string(forKey: Keys.validatorEmail) ?? ""
        validatorName = defaults.string(forKey: Keys.validatorName) ?? ""
    }
}
