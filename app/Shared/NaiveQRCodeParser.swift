import Foundation

enum NaiveQRCodeParser {
    enum ParseError: LocalizedError {
        case emptyPayload
        case unsupportedFormat
        case invalidJSON
        case invalidShareLink
        case missingHost

        var errorDescription: String? {
            switch self {
            case .emptyPayload:
                return L10n.tr("The QR code is empty.")
            case .unsupportedFormat:
                return L10n.tr("Unsupported QR format. Expected a Naive share link or JSON config.")
            case .invalidJSON:
                return L10n.tr("The QR code contains invalid JSON.")
            case .invalidShareLink:
                return L10n.tr("The QR code contains an invalid Naive share link.")
            case .missingHost:
                return L10n.tr("The imported config is missing a host.")
            }
        }
    }

    static func parse(_ payload: String) throws -> NaiveServerProfile {
        let trimmedPayload = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPayload.isEmpty else {
            throw ParseError.emptyPayload
        }

        if trimmedPayload.first == "{" {
            return try parseJSON(trimmedPayload)
        }

        return try parseShareLink(trimmedPayload)
    }

    private static func parseJSON(_ payload: String) throws -> NaiveServerProfile {
        guard let data = payload.data(using: .utf8) else {
            throw ParseError.invalidJSON
        }

        let jsonObject: Any
        do {
            jsonObject = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw ParseError.invalidJSON
        }

        guard let json = jsonObject as? [String: Any] else {
            throw ParseError.invalidJSON
        }

        let host = stringValue(in: json, keys: ["host", "server"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !host.isEmpty else {
            throw ParseError.missingHost
        }

        let title = stringValue(in: json, keys: ["title", "name", "remarks"]) ?? ""
        let user = stringValue(in: json, keys: ["user", "username"]) ?? ""
        let password = stringValue(in: json, keys: ["password"]) ?? ""
        let port = stringValue(in: json, keys: ["port"]) ?? "443"
        let typeValue = stringValue(in: json, keys: ["type", "mode"]) ?? NaiveProxyType.https.rawValue

        return NaiveServerProfile(
            name: title,
            host: host,
            type: proxyType(from: typeValue),
            port: port,
            user: user,
            password: password
        )
    }

    private static func parseShareLink(_ payload: String) throws -> NaiveServerProfile {
        let lowered = payload.lowercased()
        let type: NaiveProxyType

        if lowered.hasPrefix("naive+quic://") || lowered.hasPrefix("quic://") || lowered.hasPrefix("http3://") {
            type = .http3
        } else if lowered.hasPrefix("http2://") {
            type = .http2
        } else if lowered.hasPrefix("naive+https://") || lowered.hasPrefix("https://") {
            type = .https
        } else {
            throw ParseError.unsupportedFormat
        }

        guard let authority = rawAuthority(in: payload) else {
            throw ParseError.invalidShareLink
        }

        let resolvedAuthority: String
        if authority.contains("@") {
            resolvedAuthority = authority
        } else if let decodedAuthority = decodeBase64Authority(authority) {
            resolvedAuthority = decodedAuthority
        } else {
            throw ParseError.invalidShareLink
        }

        let fragment = decodedFragment(in: payload)
        return try profile(fromAuthority: resolvedAuthority, type: type, name: fragment)
    }

    private static func profile(fromAuthority authority: String, type: NaiveProxyType, name: String?) throws -> NaiveServerProfile {
        let rawUserInfo: String
        let rawAddress: String

        if let separatorIndex = authority.lastIndex(of: "@") {
            rawUserInfo = String(authority[..<separatorIndex])
            rawAddress = String(authority[authority.index(after: separatorIndex)...])
        } else {
            rawUserInfo = ""
            rawAddress = authority
        }

        let decodedUserInfo = rawUserInfo.removingPercentEncoding ?? rawUserInfo
        let user: String
        let password: String
        if decodedUserInfo.contains(":") {
            let credentials = decodedUserInfo.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            user = String(credentials[0])
            password = credentials.count > 1 ? String(credentials[1]) : ""
        } else {
            user = ""
            password = decodedUserInfo
        }

        let addressComponents = splitHostAndPort(rawAddress)
        let host = addressComponents.host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty else {
            throw ParseError.missingHost
        }

        return NaiveServerProfile(
            name: name ?? "",
            host: host,
            type: type,
            port: addressComponents.port ?? "443",
            user: user,
            password: password
        )
    }

    private static func stringValue(in dictionary: [String: Any], keys: [String]) -> String? {
        for key in keys {
            guard let value = dictionary.first(where: { $0.key.caseInsensitiveCompare(key) == .orderedSame })?.value else {
                continue
            }

            if let string = value as? String {
                return string
            }

            if let number = value as? NSNumber {
                return number.stringValue
            }
        }

        return nil
    }

    private static func proxyType(from value: String) -> NaiveProxyType {
        switch value.uppercased() {
        case "HTTP/3", "HTTP3", "QUIC":
            return .http3
        case "HTTP/2", "HTTP2":
            return .http2
        case "HTTPS":
            return .https
        default:
            return .https
        }
    }

    private static func rawAuthority(in payload: String) -> String? {
        guard let schemeRange = payload.range(of: "://") else {
            return nil
        }

        let startIndex = schemeRange.upperBound
        let tail = payload[startIndex...]
        let endIndex = tail.firstIndex(where: { $0 == "/" || $0 == "?" || $0 == "#" }) ?? payload.endIndex
        return String(payload[startIndex..<endIndex])
    }

    private static func decodedFragment(in payload: String) -> String? {
        guard let fragmentIndex = payload.firstIndex(of: "#") else {
            return nil
        }

        let fragment = String(payload[payload.index(after: fragmentIndex)...])
        let decoded = fragment.removingPercentEncoding ?? fragment
        return decoded.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : decoded
    }

    private static func decodeBase64Authority(_ value: String) -> String? {
        let cleanedValue = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let remainder = cleanedValue.count % 4
        let paddedValue = remainder == 0 ? cleanedValue : cleanedValue + String(repeating: "=", count: 4 - remainder)

        guard
            let data = Data(base64Encoded: paddedValue),
            let decodedValue = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        return decodedValue
    }

    private static func splitHostAndPort(_ value: String) -> (host: String, port: String?) {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedValue.hasPrefix("["),
           let closingBracketIndex = trimmedValue.firstIndex(of: "]") {
            let host = String(trimmedValue[trimmedValue.index(after: trimmedValue.startIndex)..<closingBracketIndex])
            let portStartIndex = trimmedValue.index(after: closingBracketIndex)
            if portStartIndex < trimmedValue.endIndex, trimmedValue[portStartIndex] == ":" {
                let port = String(trimmedValue[trimmedValue.index(after: portStartIndex)...])
                return (host, port.isEmpty ? nil : port)
            }
            return (host, nil)
        }

        let parts = trimmedValue.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        if parts.count == 2, parts[1].allSatisfy(\.isNumber) {
            return (String(parts[0]), String(parts[1]))
        }

        return (trimmedValue, nil)
    }

    /// Builds a share URL that `parse(_:)` can read back. Returns `nil` when the profile has no host.
    static func shareLinkString(for profile: NaiveServerProfile) -> String? {
        let host = profile.trimmedHost
        guard !host.isEmpty else {
            return nil
        }

        let scheme: String
        switch profile.type {
        case .https:
            scheme = "naive+https"
        case .http2:
            scheme = "http2"
        case .http3:
            scheme = "naive+quic"
        }

        let authority = buildShareAuthority(for: profile)
        var result = "\(scheme)://\(authority)"
        if !profile.trimmedName.isEmpty {
            let encoded = profile.name.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? profile.name
            result += "#\(encoded)"
        }
        return result
    }

    private static func buildShareAuthority(for profile: NaiveServerProfile) -> String {
        let hostPort = formatHostPort(host: profile.trimmedHost, port: profile.port)
        let user = profile.trimmedUser
        let password = profile.password

        if user.isEmpty && password.isEmpty {
            return "@\(hostPort)"
        }

        let encodedUser = percentEncodeUserInfoComponent(user)
        let encodedPassword = percentEncodeUserInfoComponent(password)

        if user.isEmpty {
            return ":\(encodedPassword)@\(hostPort)"
        }

        return "\(encodedUser):\(encodedPassword)@\(hostPort)"
    }

    private static func formatHostPort(host: String, port: String) -> String {
        let portString = port.isEmpty ? "443" : port
        if host.contains(":"), !host.hasPrefix("[") {
            return "[\(host)]:\(portString)"
        }
        return "\(host):\(portString)"
    }

    private static func percentEncodeUserInfoComponent(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}
