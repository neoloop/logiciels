import Foundation

/// Persists the last-used recipient email address per service, so it only needs to be
/// typed once (mirrors the "adresses sauvegardées automatiquement" behavior of the
/// reference dashboard).
enum EmailRecipientStore {
    private static func key(forService serviceCode: Int) -> String {
        "budgetExcel.email.service.\(serviceCode)"
    }

    static func recipient(forService serviceCode: Int) -> String? {
        UserDefaults.standard.string(forKey: key(forService: serviceCode))
    }

    static func save(_ email: String, forService serviceCode: Int) {
        UserDefaults.standard.set(email, forKey: key(forService: serviceCode))
    }
}
