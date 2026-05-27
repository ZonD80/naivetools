import Foundation
import Network

enum NaiveConfigBuilder {
    struct RemoteDNSServer {
        let transport: RemoteDNSTransport
        let server: String
        let port: Int
        let path: String?
        let tlsServerName: String?
    }

    enum BuildError: LocalizedError {
        case missingHost
        case missingUser
        case missingPassword
        case invalidPort
        case missingCustomDNSServer
        case missingCustomDNSTLSName
        case invalidCustomDNSPort
        case invalidCustomDNSPath

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
            case .missingCustomDNSServer:
                return L10n.tr("DNS server is required.")
            case .missingCustomDNSTLSName:
                return L10n.tr("DNS TLS name is required when the server is an IP address.")
            case .invalidCustomDNSPort:
                return L10n.tr("DNS port must be a number between 1 and 65535.")
            case .invalidCustomDNSPath:
                return L10n.tr("DNS path must start with /.")
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

        let remoteDNS = try remoteDNSServer(for: profile)
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
                    remoteDNSServerEntry(for: remoteDNS),
                ],
                "final": "remote-dns",
                "strategy": "ipv4_only",
            ],
            "inbounds": [
                [
                    "type": "tun",
                    "tag": "tun-in",
                    "address": [
                        "172.19.0.1/30",
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

    private static func remoteDNSServerEntry(for remoteDNS: RemoteDNSServer) -> [String: Any] {
        var entry: [String: Any] = [
            "tag": "remote-dns",
            "server": remoteDNS.server,
            "server_port": remoteDNS.port,
            "detour": "naive-out",
        ]

        switch remoteDNS.transport {
        case .doh:
            entry["type"] = "https"
            entry["path"] = remoteDNS.path ?? "/dns-query"
            entry["tls"] = [
                "enabled": true,
                "server_name": remoteDNS.tlsServerName ?? remoteDNS.server,
            ]
        case .udp:
            entry["type"] = "udp"
        }

        return entry
    }

    private static func remoteDNSServer(for profile: NaiveServerProfile) throws -> RemoteDNSServer {
        switch profile.remoteDNSPreset {
        case .cloudflare:
            return presetServer(
                transport: profile.remoteDNSTransport,
                server: "1.1.1.1",
                tlsServerName: "cloudflare-dns.com"
            )
        case .google:
            return presetServer(
                transport: profile.remoteDNSTransport,
                server: "8.8.8.8",
                tlsServerName: "dns.google"
            )
        case .quad9:
            return presetServer(
                transport: profile.remoteDNSTransport,
                server: "9.9.9.9",
                tlsServerName: "dns.quad9.net"
            )
        case .custom:
            return try customServer(for: profile)
        }
    }

    private static func presetServer(
        transport: RemoteDNSTransport,
        server: String,
        tlsServerName: String
    ) -> RemoteDNSServer {
        switch transport {
        case .doh:
            return RemoteDNSServer(
                transport: .doh,
                server: server,
                port: 443,
                path: "/dns-query",
                tlsServerName: tlsServerName
            )
        case .udp:
            return RemoteDNSServer(
                transport: .udp,
                server: server,
                port: 53,
                path: nil,
                tlsServerName: nil
            )
        }
    }

    private static func customServer(for profile: NaiveServerProfile) throws -> RemoteDNSServer {
        let server = profile.trimmedCustomDNSServer
        guard !server.isEmpty else {
            throw BuildError.missingCustomDNSServer
        }

        let defaultPort = profile.remoteDNSTransport.usesDoH ? 443 : 53
        let portString = profile.customDNSPort.trimmingCharacters(in: .whitespacesAndNewlines)
        let port = Int(portString.isEmpty ? String(defaultPort) : portString)
        guard let port, (1 ... 65_535).contains(port) else {
            throw BuildError.invalidCustomDNSPort
        }

        switch profile.remoteDNSTransport {
        case .doh:
            let path = profile.trimmedCustomDNSPath.isEmpty ? "/dns-query" : profile.trimmedCustomDNSPath
            guard path.hasPrefix("/") else {
                throw BuildError.invalidCustomDNSPath
            }

            let tlsServerName: String
            if isIPAddress(server) {
                let tlsName = profile.trimmedCustomDNSTLSName
                guard !tlsName.isEmpty else {
                    throw BuildError.missingCustomDNSTLSName
                }
                tlsServerName = tlsName
            } else {
                tlsServerName = profile.trimmedCustomDNSTLSName.isEmpty ? server : profile.trimmedCustomDNSTLSName
            }

            return RemoteDNSServer(
                transport: .doh,
                server: server,
                port: port,
                path: path,
                tlsServerName: tlsServerName
            )
        case .udp:
            return RemoteDNSServer(
                transport: .udp,
                server: server,
                port: port,
                path: nil,
                tlsServerName: nil
            )
        }
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
