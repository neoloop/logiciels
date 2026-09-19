import Foundation

/// How the app gets its ticket data.
enum ConnectionMode: String, CaseIterable, Identifiable, Codable {
    /// Talks live to the GLPI REST API. Requires the phone to actually
    /// reach the GLPI server (same network, or a VPN into it).
    case direct

    /// Reads a static JSON snapshot (see tools/glpi-onedrive-export),
    /// typically synced via OneDrive from a machine that stays on the
    /// GLPI network. Works from anywhere, but read-only and only as
    /// fresh as the last export.
    case fileExport

    var id: String { rawValue }

    var label: String {
        switch self {
        case .direct: return "Direct (VPN / réseau GLPI)"
        case .fileExport: return "Fichier partagé (OneDrive)"
        }
    }
}
