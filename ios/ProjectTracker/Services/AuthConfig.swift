import Foundation

/// Values to fill in after creating the Azure AD app registration — see docs/SETUP.md.
enum AuthConfig {
    /// "Application (client) ID" from the Azure app registration overview page.
    static let clientId = "REPLACE_WITH_YOUR_CLIENT_ID"

    /// The iOS/macOS platform redirect URI Azure generates from your bundle identifier,
    /// of the form "msauth.<your.bundle.id>://auth". Copy it exactly from the Azure portal.
    static let redirectUri = "msauth.REPLACE_WITH_YOUR_BUNDLE_ID://auth"

    /// Path (from the OneDrive root) to the shared workbook both the app and the web page use.
    static let workbookPath = "/me/drive/root:/ProjectTracker.xlsx:/workbook"
}
