import Foundation

/// Persists the last-used recipient email address per service, so it only needs to be
/// typed once (mirrors the "adresses sauvegardées automatiquement" behavior of the
/// reference dashboard).
enum EmailRecipientStore {
    private static func storageKey(_ key: String) -> String {
        "budgetExcel.email.\(key)"
    }

    static func recipient(forKey key: String) -> String? {
        UserDefaults.standard.string(forKey: storageKey(key))
    }

    static func save(_ email: String, forKey key: String) {
        UserDefaults.standard.set(email, forKey: storageKey(key))
    }

    static func recipient(forService serviceCode: Int) -> String? {
        recipient(forKey: "service.\(serviceCode)")
    }

    static func save(_ email: String, forService serviceCode: Int) {
        save(email, forKey: "service.\(serviceCode)")
    }
}
