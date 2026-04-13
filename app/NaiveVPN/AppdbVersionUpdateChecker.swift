import Combine
import Foundation

/// Reimplements appdb’s `universal_gateway/` check from AppdbSDK (multipart POST, same response shape).
@MainActor
final class AppdbVersionUpdateChecker: ObservableObject {
    @Published private(set) var isNewerVersionAvailable = false
    @Published private(set) var storeVersion: String?

    private var didCheckThisSession = false

    func refreshIfNeeded() async {
        guard !didCheckThisSession else {
            return
        }
        didCheckThisSession = true

        guard
            let installed = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            !installed.isEmpty
        else {
            return
        }

        let endpoint = AppConfiguration.appdbAPIBaseURL.appendingPathComponent("universal_gateway/")
        var multipart = AppdbMultipartForm()
        multipart.add(key: "universal_object_identifier", value: AppConfiguration.appdbUniversalObjectIdentifier)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(multipart.httpContentTypeHeaderValue, forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = multipart.httpBody
        request.timeoutInterval = 20

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            let envelope = try decoder.decode(AppdbUniversalGatewayEnvelope.self, from: data)
            guard envelope.success else {
                return
            }

            let remote = envelope.data.object.version
            storeVersion = remote

            switch installed.compare(remote, options: .numeric) {
            case .orderedAscending:
                isNewerVersionAvailable = true
            case .orderedSame, .orderedDescending:
                isNewerVersionAvailable = false
            }
        } catch {
            return
        }
    }
}

// MARK: - API response (matches AppdbSDK `AppDataModel`)

private struct AppdbUniversalGatewayEnvelope: Decodable {
    let success: Bool
    let data: AppdbGatewayDataBlock
}

private struct AppdbGatewayDataBlock: Decodable {
    let object: AppdbGatewayObject
}

private struct AppdbGatewayObject: Decodable {
    let version: String
}

// MARK: - Multipart (same layout as AppdbSDK `MultipartRequest`)

private struct AppdbMultipartForm {
    private let boundary: String
    private let separator = "\r\n"
    private var body = Data()

    init(boundary: String = UUID().uuidString) {
        self.boundary = boundary
    }

    mutating func add(key: String, value: String) {
        body.append("--\(boundary)\(separator)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(key)\"\(separator)".data(using: .utf8)!)
        body.append(separator.data(using: .utf8)!)
        body.append(value.data(using: .utf8)!)
        body.append(separator.data(using: .utf8)!)
    }

    var httpContentTypeHeaderValue: String {
        "multipart/form-data; boundary=\(boundary)"
    }

    var httpBody: Data {
        var copy = body
        copy.append("--\(boundary)--".data(using: .utf8)!)
        return copy
    }
}
