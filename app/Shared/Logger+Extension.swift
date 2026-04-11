import Foundation
import os

extension Logger {
    init(category: String) {
        self.init(
            subsystem: Bundle.main.bundleIdentifier ?? AppConfiguration.basePackageIdentifier,
            category: category
        )
    }
}
