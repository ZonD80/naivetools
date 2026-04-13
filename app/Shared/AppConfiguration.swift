import Foundation

enum AppConfiguration {
    /// appdb universal object id (details: https://appdb.to/details/<id>)
    static let appdbUniversalObjectIdentifier = "8ca8a41db219d2c36acca881628efb1d26e32115"

    static var appdbAppDetailsURL: URL {
        URL(string: "https://appdb.to/details/\(appdbUniversalObjectIdentifier)")!
    }

    /// Same API base as AppdbSDK: `https://api.dbservices.to/v1.7/`
    static let appdbAPIBaseURL = URL(string: "https://api.dbservices.to/v1.7/")!

    static var basePackageIdentifier: String {
        Bundle.main.bundleIdentifier?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty
            ?? (Bundle.main.object(forInfoDictionaryKey: "BasePackageIdentifier") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty
            ?? "com.example.naivevpn"
    }

    static var extensionBundleIdentifier: String {
        "\(basePackageIdentifier).extension"
    }

    static var appName: String {
        L10n.tr("Naive VPN")
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
