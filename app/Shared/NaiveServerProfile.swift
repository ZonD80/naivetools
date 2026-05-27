import Foundation

enum RemoteDNSTransport: String, CaseIterable, Codable, Identifiable {
    case doh = "DoH"
    case udp = "UDP"

    var id: String { rawValue }

    var pickerTitle: String {
        switch self {
        case .doh:
            return L10n.tr("DoH")
        case .udp:
            return L10n.tr("UDP")
        }
    }

    var usesDoH: Bool {
        self == .doh
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)

        switch value.uppercased() {
        case "DOH", "HTTPS":
            self = .doh
        case "UDP", "TCP":
            self = .udp
        default:
            self = .doh
        }
    }
}

enum RemoteDNSPreset: String, CaseIterable, Codable, Identifiable {
    case cloudflare = "Cloudflare"
    case google = "Google"
    case quad9 = "Quad9"
    case custom = "Custom"

    var id: String { rawValue }

    var pickerTitle: String {
        switch self {
        case .cloudflare:
            return L10n.tr("Cloudflare")
        case .google:
            return L10n.tr("Google")
        case .quad9:
            return L10n.tr("Quad9")
        case .custom:
            return L10n.tr("Custom")
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)

        switch value {
        case Self.cloudflare.rawValue:
            self = .cloudflare
        case Self.google.rawValue:
            self = .google
        case Self.quad9.rawValue:
            self = .quad9
        case Self.custom.rawValue:
            self = .custom
        default:
            self = .cloudflare
        }
    }
}

/// Transport modes for sing-box naive outbound and share URIs.
/// naiveproxy proxy URIs are `https` or `quic`; v2rayN uses `naive+https://` and `naive+quic://`.
/// HTTPS and HTTP/2 here share the same tunnel (HTTP/2 over TLS, sing-box `quic` false); QUIC is HTTP/3 (`quic` true).
enum NaiveProxyType: String, CaseIterable, Codable, Identifiable {
    case https = "HTTPS"
    case http2 = "HTTP/2"
    case http3 = "QUIC"

    static var allCases: [NaiveProxyType] {
        [.https, .http2, .http3]
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
            self = .https
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
    var type: NaiveProxyType = .https
    var port: String = "443"
    var user: String = ""
    var password: String = ""
    var remoteDNSPreset: RemoteDNSPreset = .cloudflare
    var remoteDNSTransport: RemoteDNSTransport = .doh
    var customDNSServer: String = ""
    var customDNSTLSName: String = ""
    var customDNSPath: String = "/dns-query"
    var customDNSPort: String = "443"

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case host
        case type
        case port
        case user
        case password
        case remoteDNSPreset
        case remoteDNSTransport
        case customDNSServer
        case customDNSTLSName
        case customDNSPath
        case customDNSPort
    }

    init(
        id: UUID = UUID(),
        name: String = "",
        host: String = "",
        type: NaiveProxyType = .https,
        port: String = "443",
        user: String = "",
        password: String = "",
        remoteDNSPreset: RemoteDNSPreset = .cloudflare,
        remoteDNSTransport: RemoteDNSTransport = .doh,
        customDNSServer: String = "",
        customDNSTLSName: String = "",
        customDNSPath: String = "/dns-query",
        customDNSPort: String = "443"
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.type = type
        self.port = port
        self.user = user
        self.password = password
        self.remoteDNSPreset = remoteDNSPreset
        self.remoteDNSTransport = remoteDNSTransport
        self.customDNSServer = customDNSServer
        self.customDNSTLSName = customDNSTLSName
        self.customDNSPath = customDNSPath
        self.customDNSPort = customDNSPort
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        host = try container.decodeIfPresent(String.self, forKey: .host) ?? ""
        type = try container.decodeIfPresent(NaiveProxyType.self, forKey: .type) ?? .https
        port = try container.decodeIfPresent(String.self, forKey: .port) ?? "443"
        user = try container.decodeIfPresent(String.self, forKey: .user) ?? ""
        password = try container.decodeIfPresent(String.self, forKey: .password) ?? ""
        remoteDNSPreset = try container.decodeIfPresent(RemoteDNSPreset.self, forKey: .remoteDNSPreset) ?? .cloudflare
        remoteDNSTransport = try container.decodeIfPresent(RemoteDNSTransport.self, forKey: .remoteDNSTransport) ?? .doh
        customDNSServer = try container.decodeIfPresent(String.self, forKey: .customDNSServer) ?? ""
        customDNSTLSName = try container.decodeIfPresent(String.self, forKey: .customDNSTLSName) ?? ""
        customDNSPath = try container.decodeIfPresent(String.self, forKey: .customDNSPath) ?? "/dns-query"
        customDNSPort = try container.decodeIfPresent(String.self, forKey: .customDNSPort) ?? "443"
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

    var trimmedCustomDNSServer: String {
        customDNSServer.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedCustomDNSTLSName: String {
        customDNSTLSName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedCustomDNSPath: String {
        customDNSPath.trimmingCharacters(in: .whitespacesAndNewlines)
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
