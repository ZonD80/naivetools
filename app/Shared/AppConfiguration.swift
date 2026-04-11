import Foundation

enum AppConfiguration {
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
