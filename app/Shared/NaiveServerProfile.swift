import Foundation

/// Transport modes for sing-box naive outbound and share URIs.
/// naiveproxy proxy URIs are `https` or `quic`; v2rayN uses `naive+https://` and `naive+quic://`.
/// HTTPS and HTTP/2 here share the same tunnel (HTTP/2 over TLS, sing-box `quic` false); QUIC is HTTP/3 (`quic` true).
enum NaiveProxyType: String, CaseIterable, Codable, Identifiable {
    case https = "HTTPS"
    case http2 = "HTTP/2"
    case http3 = "QUIC"

    static var allCases: [NaiveProxyType] {
        [.http3, .https, .http2]
    }

    var id: String { rawValue }

    /// Short label for pickers (aligned with naiveproxy / v2rayN naming).
    var pickerTitle: String {
        switch self {
        case .https:
            return L10n.tr("HTTPS")
        case .http2:
            return L10n.tr("HTTP/2")
        case .http3:
            return L10n.tr("QUIC")
        }
    }

    var usesQUIC: Bool {
        self == .http3
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)

        switch value.uppercased() {
        case "HTTP/3", "QUIC":
            self = .http3
        case "HTTP/2":
            self = .http2
        case "HTTPS":
            self = .https
        default:
            self = .http3
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct NaiveServerProfile: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var name: String = ""
    var host: String = ""
    var type: NaiveProxyType = .http3
    var port: String = "443"
    var user: String = ""
    var password: String = ""

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case host
        case type
        case port
        case user
        case password
    }

    init(
        id: UUID = UUID(),
        name: String = "",
        host: String = "",
        type: NaiveProxyType = .http3,
        port: String = "443",
        user: String = "",
        password: String = ""
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.type = type
        self.port = port
        self.user = user
        self.password = password
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        host = try container.decodeIfPresent(String.self, forKey: .host) ?? ""
        type = try container.decodeIfPresent(NaiveProxyType.self, forKey: .type) ?? .http3
        port = try container.decodeIfPresent(String.self, forKey: .port) ?? "443"
        user = try container.decodeIfPresent(String.self, forKey: .user) ?? ""
        password = try container.decodeIfPresent(String.self, forKey: .password) ?? ""
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedHost: String {
        host.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedUser: String {
        user.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedPassword: String {
        password.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var displayName: String {
        if !trimmedName.isEmpty {
            return trimmedName
        }

        if !trimmedHost.isEmpty {
            return trimmedHost
        }

        return L10n.tr("Untitled")
    }
}
