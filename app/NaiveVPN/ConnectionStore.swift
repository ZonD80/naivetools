import Foundation
import NetworkExtension
import os

private enum PublicIPAddressService {
    static let url = URL(string: "https://whatismyip.akamai.com")!

    static func fetch() async -> String? {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard
                let httpResponse = response as? HTTPURLResponse,
                (200..<300).contains(httpResponse.statusCode)
            else {
                return nil
            }

            let ipAddress = String(decoding: data, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return ipAddress.isEmpty ? nil : ipAddress
        } catch {
            return nil
        }
    }
}

@MainActor
final class ConnectionStore: ObservableObject {
    @Published var profile: NaiveServerProfile {
        didSet {
            persistCurrentProfile()
        }
    }
    @Published var selectedProfileID: UUID {
        didSet {
            guard oldValue != selectedProfileID else {
                return
            }

            loadSelectedProfile()
        }
    }
    @Published private(set) var profiles: [NaiveServerProfile]

    @Published private(set) var status: NEVPNStatus = .invalid {
        didSet {
            guard oldValue != status else {
                return
            }

            switch status {
            case .connected, .disconnected:
                refreshPublicIPAddress()
            default:
                break
            }
        }
    }
    @Published private(set) var publicIPAddress = L10n.tr("Checking...")
    @Published var errorMessage: String?

    private let logger = Logger(category: "ConnectionStore")
    private var manager: NETunnelProviderManager?
    private var observer: NSObjectProtocol?
    private var publicIPAddressTask: Task<Void, Never>?

    init() {
        let library = NaiveProfileStore.loadLibrary()
        profiles = library.profiles
        selectedProfileID = library.selectedProfileID
        profile = library.selectedProfile
        refreshPublicIPAddress()

        Task {
            await refreshManager()
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        publicIPAddressTask?.cancel()
    }

    var isBusy: Bool {
        switch status {
        case .connecting, .disconnecting:
            return true
        default:
            return false
        }
    }

    var actionTitle: String {
        isConnected ? L10n.tr("Disconnect") : L10n.tr("Connect")
    }

    /// SF Symbol name for the main connect/disconnect control (paired with `actionTitle` for accessibility).
    var connectionToggleIconName: String {
        isConnected ? "stop.circle.fill" : "play.circle.fill"
    }

    var canDeleteProfile: Bool {
        profiles.count > 1
    }

    var statusText: String {
        switch status {
        case .invalid:
            return L10n.tr("Invalid")
        case .disconnected:
            return L10n.tr("Disconnected")
        case .connecting:
            return L10n.tr("Connecting")
        case .connected:
            return L10n.tr("Connected")
        case .reasserting:
            return L10n.tr("Reconnecting")
        case .disconnecting:
            return L10n.tr("Disconnecting")
        @unknown default:
            return L10n.tr("Unknown")
        }
    }

    func createProfile() {
        let newProfile = NaiveServerProfile(name: nextNewProfileName())
        profiles.append(newProfile)
        selectedProfileID = newProfile.id
    }

    func duplicateSelectedProfile() {
        var duplicatedProfile = profile
        duplicatedProfile.id = UUID()
        duplicatedProfile.name = nextDuplicateProfileName(from: profile)
        profiles.append(duplicatedProfile)
        selectedProfileID = duplicatedProfile.id
    }

    func deleteSelectedProfile() {
        guard
            profiles.count > 1,
            let selectedIndex = profiles.firstIndex(where: { $0.id == selectedProfileID })
        else {
            return
        }

        profiles.remove(at: selectedIndex)
        let nextIndex = min(selectedIndex, profiles.count - 1)
        selectedProfileID = profiles[nextIndex].id
    }

    func importProfile(fromQRCodePayload payload: String) throws {
        var importedProfile = try NaiveQRCodeParser.parse(payload)

        if importedProfile.trimmedName.isEmpty, importedProfile.trimmedHost.isEmpty {
            importedProfile.name = nextNewProfileName()
        }

        if shouldReplaceSelectedProfile {
            importedProfile.id = profile.id
        } else {
            importedProfile.id = UUID()
            importedProfile.name = uniqueImportedProfileName(for: importedProfile)
        }

        profile = importedProfile
    }

    func toggleConnection() {
        Task {
            do {
                if isConnected {
                    try await disconnect()
                } else {
                    try await connect()
                }
            } catch {
                errorMessage = error.localizedDescription
                logger.error("Tunnel action failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private var isConnected: Bool {
        switch status {
        case .connected, .connecting, .reasserting:
            return true
        default:
            return false
        }
    }

    private func connect() async throws {
        let configContent = try NaiveConfigBuilder.buildConfig(from: profile)
        let manager = try await prepareManager(serverAddress: profile.trimmedHost)
        let options: [String: NSObject] = [
            "configContent": NSString(string: configContent),
        ]

        do {
            try manager.connection.startVPNTunnel(options: options)
        } catch {
            try await manager.loadPreferences()
            self.manager = manager
            registerStatusObserver(for: manager.connection)
            status = manager.connection.status
            throw error
        }

        self.manager = manager
        registerStatusObserver(for: manager.connection)
        status = manager.connection.status
    }

    private func disconnect() async throws {
        let manager = try await getOrCreateManager()
        manager.connection.stopVPNTunnel()
        self.manager = manager
        registerStatusObserver(for: manager.connection)
        status = manager.connection.status
    }

    private func refreshManager() async {
        do {
            let manager = try await findManager()
            self.manager = manager
            if let manager {
                registerStatusObserver(for: manager.connection)
                status = manager.connection.status
            } else {
                status = .disconnected
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func getOrCreateManager() async throws -> NETunnelProviderManager {
        if let manager {
            return manager
        }
        return try await prepareManager(serverAddress: profile.trimmedHost)
    }

    private func prepareManager(serverAddress: String) async throws -> NETunnelProviderManager {
        let manager = try await findManager() ?? NETunnelProviderManager()
        let tunnelProtocol = NETunnelProviderProtocol()

        tunnelProtocol.providerBundleIdentifier = AppConfiguration.extensionBundleIdentifier
        tunnelProtocol.serverAddress = serverAddress.isEmpty ? "NaiveProxy" : serverAddress
        tunnelProtocol.disconnectOnSleep = false
        manager.localizedDescription = AppConfiguration.appName
        manager.protocolConfiguration = tunnelProtocol
        manager.isEnabled = true

        try await manager.savePreferences()
        try await manager.loadPreferences()

        self.manager = manager
        registerStatusObserver(for: manager.connection)
        status = manager.connection.status
        return manager
    }

    private func findManager() async throws -> NETunnelProviderManager? {
        let managers = try await NETunnelProviderManager.loadAllManagers()
        return managers.first(where: {
            guard let proto = $0.protocolConfiguration as? NETunnelProviderProtocol else {
                return false
            }
            return proto.providerBundleIdentifier == AppConfiguration.extensionBundleIdentifier
        })
    }

    private func registerStatusObserver(for connection: NEVPNConnection) {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }

        observer = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: connection,
            queue: .main
        ) { [weak self] notification in
            guard
                let self,
                let connection = notification.object as? NEVPNConnection
            else {
                return
            }

            Task { @MainActor [weak self] in
                self?.status = connection.status
            }
        }
    }

    private func loadSelectedProfile() {
        guard let selectedProfile = profiles.first(where: { $0.id == selectedProfileID }) else {
            if let firstProfile = profiles.first {
                selectedProfileID = firstProfile.id
            }
            return
        }

        profile = selectedProfile
        persistLibrary()
    }

    private func persistCurrentProfile() {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else {
            profiles.append(profile)
            selectedProfileID = profile.id
            return
        }

        profiles[index] = profile
        persistLibrary()
    }

    private func refreshPublicIPAddress() {
        publicIPAddressTask?.cancel()
        publicIPAddress = L10n.tr("Checking...")

        publicIPAddressTask = Task { [weak self] in
            let ipAddress = await PublicIPAddressService.fetch() ?? L10n.tr("Unavailable")
            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                self?.publicIPAddress = ipAddress
            }
        }
    }

    private func persistLibrary() {
        NaiveProfileStore.saveLibrary(
            NaiveProfileLibrary(profiles: profiles, selectedProfileID: selectedProfileID)
        )
    }

    private var shouldReplaceSelectedProfile: Bool {
        profiles.count == 1
            && profile.trimmedName.isEmpty
            && profile.trimmedHost.isEmpty
            && profile.trimmedUser.isEmpty
            && profile.trimmedPassword.isEmpty
            && (profile.port == "443" || profile.port.isEmpty)
    }

    private func nextNewProfileName() -> String {
        var index = 1
        while true {
            let candidate = L10n.configName(index)
            if !profiles.contains(where: { $0.displayName.caseInsensitiveCompare(candidate) == .orderedSame }) {
                return candidate
            }
            index += 1
        }
    }

    private func nextDuplicateProfileName(from sourceProfile: NaiveServerProfile) -> String {
        let baseName = sourceProfile.displayName
        var candidate = L10n.copiedName(from: baseName)
        var index = 2

        while profiles.contains(where: { $0.displayName.caseInsensitiveCompare(candidate) == .orderedSame }) {
            candidate = L10n.copiedName(from: baseName, copyIndex: index)
            index += 1
        }

        return candidate
    }

    private func uniqueImportedProfileName(for profile: NaiveServerProfile) -> String {
        let baseName = profile.displayName
        guard profiles.contains(where: { $0.displayName.caseInsensitiveCompare(baseName) == .orderedSame }) else {
            return profile.name
        }

        var index = 2
        while true {
            let candidate = "\(baseName) \(index)"
            if !profiles.contains(where: { $0.displayName.caseInsensitiveCompare(candidate) == .orderedSame }) {
                return candidate
            }
            index += 1
        }
    }
}
