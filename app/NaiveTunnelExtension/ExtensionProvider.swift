import Foundation
import Libbox
import NetworkExtension
import os

class ExtensionProvider: NEPacketTunnelProvider {
    private static let logger = Logger(category: "ExtensionProvider")

    private(set) var commandServer: LibboxCommandServer?
    private lazy var platformInterface = ExtensionPlatformInterface(self)
    private var tunnelOptions: [String: NSObject]?
    private var startOptionsURL: URL?

    struct OverridePreferences {
        var includeAllNetworks = false
        var systemProxyEnabled = true
        var excludeDefaultRoute = false
        var autoRouteUseSubRangesByDefault = false
        var excludeAPNsRoute = false
    }

    var overridePreferences: OverridePreferences?

    override init() {
        LibboxPrepareCrashSignalHandlers()
        super.init()
        LibboxReinstallCrashSignalHandlers()
    }

    override func startTunnel(options startOptions: [String: NSObject]?) async throws {
        let libraryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let workingURL = cacheURL.appendingPathComponent("Working", isDirectory: true)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("NaiveVPN", isDirectory: true)

        try FileManager.default.createDirectory(at: libraryURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: workingURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)

        startOptionsURL = libraryURL.appendingPathComponent(ExtensionStartOptions.snapshotFileName)

        let effectiveOptions = try resolveStartOptions(startOptions)
        guard effectiveOptions["configContent"] as? String != nil else {
            throw ExtensionStartupError("(packet-tunnel) missing configContent in tunnel options")
        }

        try persistStartOptions(effectiveOptions)
        applyStartOptions(effectiveOptions)

        let options = LibboxSetupOptions()
        options.basePath = libraryURL.path
        options.workingPath = workingURL.path
        options.tempPath = tempURL.path
        options.logMaxLines = 1000
        options.debug = false
        options.crashReportSource = "PacketTunnel"
        options.oomKillerEnabled = true

        var setupError: NSError?
        LibboxSetup(options, &setupError)
        if let setupError {
            throw ExtensionStartupError("(packet-tunnel) setup service error: \(setupError.localizedDescription)")
        }

        var commandError: NSError?
        commandServer = LibboxNewCommandServer(platformInterface, platformInterface, &commandError)
        if let commandError {
            throw ExtensionStartupError("(packet-tunnel) create command server error: \(commandError.localizedDescription)")
        }

        do {
            try commandServer?.start()
        } catch {
            throw ExtensionStartupError("(packet-tunnel) start command server error: \(error.localizedDescription)")
        }

        try await startService()
        writeMessage("(packet-tunnel) tunnel started")
    }

    override func stopTunnel(with reason: NEProviderStopReason) async {
        Self.logger.info("Stopping tunnel, reason: \(reason.rawValue, privacy: .public)")
        stopService()
        try? await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)
        commandServer?.close()
        commandServer = nil
    }

    override func sleep() async {
        commandServer?.pause()
    }

    override func wake() {
        commandServer?.wake()
    }

    override func handleAppMessage(_ messageData: Data) async -> Data? {
        do {
            let options = try ExtensionStartOptions.decode(messageData)
            applyStartOptions(options)
            try persistStartOptions(options)
            try await reloadService()
            return nil
        } catch {
            return error.localizedDescription.data(using: .utf8)
        }
    }

    private func resolveStartOptions(_ startOptions: [String: NSObject]?) throws -> [String: NSObject] {
        if let startOptions, startOptions["configContent"] as? String != nil {
            return startOptions
        }

        guard let startOptionsURL, FileManager.default.fileExists(atPath: startOptionsURL.path) else {
            throw ExtensionStartupError("(packet-tunnel) missing start options")
        }

        let data = try Data(contentsOf: startOptionsURL)
        return try ExtensionStartOptions.decode(data)
    }

    private func persistStartOptions(_ options: [String: NSObject]) throws {
        guard let startOptionsURL else {
            return
        }

        let data = try ExtensionStartOptions.encode(options)
        try data.write(to: startOptionsURL, options: .atomic)
    }

    private func applyStartOptions(_ options: [String: NSObject]) {
        tunnelOptions = options
        overridePreferences = OverridePreferences(
            includeAllNetworks: (options["includeAllNetworks"] as? NSNumber)?.boolValue ?? false,
            systemProxyEnabled: (options["systemProxyEnabled"] as? NSNumber)?.boolValue ?? true,
            excludeDefaultRoute: (options["excludeDefaultRoute"] as? NSNumber)?.boolValue ?? false,
            autoRouteUseSubRangesByDefault: (options["autoRouteUseSubRangesByDefault"] as? NSNumber)?.boolValue ?? false,
            excludeAPNsRoute: (options["excludeAPNsRoute"] as? NSNumber)?.boolValue ?? false
        )
    }

    private func startService() async throws {
        guard let configContent = tunnelOptions?["configContent"] as? String else {
            throw ExtensionStartupError("(packet-tunnel) missing configContent in tunnel options")
        }

        let options = LibboxOverrideOptions()
        do {
            try commandServer?.startOrReloadService(configContent, options: options)
        } catch {
            throw ExtensionStartupError("(packet-tunnel) start service error: \(error.localizedDescription)")
        }
    }

    func reloadService() async throws {
        reasserting = true
        defer { reasserting = false }
        try await startService()
    }

    func stopService() {
        do {
            try commandServer?.closeService()
        } catch {
            writeMessage("(packet-tunnel) close service error: \(error.localizedDescription)")
        }
        platformInterface.reset()
    }

    func writeMessage(_ message: String) {
        commandServer?.writeMessage(2, message: message)
    }
}
