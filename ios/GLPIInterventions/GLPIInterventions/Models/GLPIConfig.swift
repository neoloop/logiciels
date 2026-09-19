import Foundation

/// Connection settings for one GLPI instance.
struct GLPIConfig: Equatable {
    /// Base URL of the GLPI install, e.g. "https://glpi.example.com".
    /// The "/apirest.php" suffix is appended automatically.
    var serverURL: URL
    var appToken: String
    var userToken: String

    var apiBaseURL: URL {
        serverURL.appendingPathComponent("apirest.php")
    }
}
