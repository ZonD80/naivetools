import Foundation
import Network

enum NaiveConfigBuilder {
    enum BuildError: LocalizedError {
        case missingHost
        case missingUser
        case missingPassword
        case invalidPort

        var errorDescription: String? {
            switch self {
            case .missingHost:
                return L10n.tr("Host is required.")
            case .missingUser:
                return L10n.tr("User is required.")
            case .missingPassword:
                return L10n.tr("Password is required.")
            case .invalidPort:
                return L10n.tr("Port must be a number between 1 and 65535.")
            }
        }
    }

    static func buildConfig(from profile: NaiveServerProfile) throws -> String {
        let host = profile.trimmedHost
        guard !host.isEmpty else {
            throw BuildError.missingHost
        }

        let user = profile.trimmedUser
        guard !user.isEmpty else {
            throw BuildError.missingUser
        }

        let password = profile.trimmedPassword
        guard !password.isEmpty else {
            throw BuildError.missingPassword
        }

        guard let port = Int(profile.port), (1 ... 65_535).contains(port) else {
            throw BuildError.invalidPort
        }

        let usesQUIC = profile.type.usesQUIC

        let naiveOutbound: [String: Any] = [
            "type": "naive",
            "tag": "naive-out",
            "server": host,
            "server_port": port,
            "username": user,
            "password": password,
            "quic": usesQUIC,
            "tls": tlsConfiguration(for: host),
        ]

        let config: [String: Any] = [
            "log": [
                "level": "info",
            ],
            "dns": [
                "servers": [
                    [
                        "type": "local",
                        "tag": "local-dns",
                    ],
                    [
                        "type": "https",
                        "tag": "remote-dns",
                        "server": "1.1.1.1",
                        "server_port": 443,
                        "path": "/dns-query",
                        "tls": [
                            "enabled": true,
                            "server_name": "cloudflare-dns.com",
                        ],
                        "detour": "naive-out",
                    ],
                ],
                "final": "remote-dns",
                "strategy": "prefer_ipv4",
            ],
            "inbounds": [
                [
                    "type": "tun",
                    "tag": "tun-in",
                    "address": [
                        "172.19.0.1/30",
                        "fdfe:dcba:9876::1/126",
                    ],
                    "auto_route": true,
                    "strict_route": true,
                ],
            ],
            "outbounds": [
                naiveOutbound,
                [
                    "type": "direct",
                    "tag": "direct",
                ],
            ],
            "route": [
                "auto_detect_interface": true,
                "default_domain_resolver": "local-dns",
                "final": "naive-out",
                "rules": [
                    [
                        "action": "sniff",
                    ],
                    [
                        "protocol": "dns",
                        "action": "hijack-dns",
                    ],
                ],
            ],
        ]

        let data = try JSONSerialization.data(
            withJSONObject: config,
            options: [.prettyPrinted, .sortedKeys]
        )
        return String(decoding: data, as: UTF8.self)
    }

    private static func tlsConfiguration(for host: String) -> [String: Any] {
        var tls: [String: Any] = [
            "enabled": true,
        ]

        if !isIPAddress(host) {
            tls["server_name"] = host
        }

        return tls
    }

    private static func isIPAddress(_ value: String) -> Bool {
        IPv4Address(value) != nil || IPv6Address(value) != nil
    }
}
