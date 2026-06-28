import Foundation

enum LocalSecretStore {
    private static let prefix = "localSecret."

    static func read(account: String) -> String {
        guard let encoded = UserDefaults.standard.string(forKey: storageKey(for: account)),
              let data = Data(base64Encoded: encoded),
              let value = String(data: data, encoding: .utf8) else {
            return ""
        }

        return value
    }

    static func save(_ value: String, account: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            delete(account: account)
            return
        }

        let encoded = Data(trimmed.utf8).base64EncodedString()
        UserDefaults.standard.set(encoded, forKey: storageKey(for: account))
    }

    static func delete(account: String) {
        UserDefaults.standard.removeObject(forKey: storageKey(for: account))
    }

    private static func storageKey(for account: String) -> String {
        "\(prefix)\(account)"
    }
}
