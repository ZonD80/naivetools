import Foundation

final class ExtensionStartupError: Error {
    let message: String

    init(_ message: String) {
        self.message = message
    }
}

extension ExtensionStartupError: LocalizedError {
    var errorDescription: String? {
        message
    }
}

extension ExtensionStartupError: CustomNSError {
    static var errorDomain: String {
        "ExtensionStartupError"
    }

    var errorCode: Int {
        1
    }

    var errorUserInfo: [String: Any] {
        [NSLocalizedDescriptionKey: message]
    }
}
