import Foundation
import Libbox
import Network
import NetworkExtension
import UserNotifications
import os

final class ExtensionPlatformInterface: NSObject, LibboxPlatformInterfaceProtocol, LibboxCommandServerHandlerProtocol {
    private static let logger = Logger(category: "ExtensionPlatformInterface")

    private let tunnel: ExtensionProvider
    private var networkSettings: NEPacketTunnelNetworkSettings?
    private var nwMonitor: Network.NWPathMonitor?

    init(_ tunnel: ExtensionProvider) {
        self.tunnel = tunnel
    }

    func openTun(_ options: LibboxTunOptionsProtocol?, ret0_: UnsafeMutablePointer<Int32>?) throws {
        try runBlocking { [self] in
            try await openTun0(options, ret0_)
        }
    }

    private func openTun0(_ options: LibboxTunOptionsProtocol?, _ tunFdPointer: UnsafeMutablePointer<Int32>?) async throws {
        guard let options else {
            throw NSError(domain: "ExtensionPlatformInterface", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "Missing TUN options.",
            ])
        }

        guard let tunFdPointer else {
            throw NSError(domain: "ExtensionPlatformInterface", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "Missing TUN file descriptor pointer.",
            ])
        }

        let prefs = tunnel.overridePreferences ?? .init()
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")

        if options.getAutoRoute() {
            settings.mtu = NSNumber(value: options.getMTU())

            let dnsServer = try options.getDNSServerAddress()
            let dnsSettings = NEDNSSettings(servers: [dnsServer.value])
            settings.dnsSettings = dnsSettings

            var ipv4Addresses: [String] = []
            var ipv4Masks: [String] = []
            let ipv4AddressIterator = options.getInet4Address()!
            while ipv4AddressIterator.hasNext() {
                let prefix = ipv4AddressIterator.next()!
                ipv4Addresses.append(prefix.address())
                ipv4Masks.append(prefix.mask())
            }

            let ipv4Settings = NEIPv4Settings(addresses: ipv4Addresses, subnetMasks: ipv4Masks)
            var ipv4Routes: [NEIPv4Route] = []
            var ipv4ExcludedRoutes: [NEIPv4Route] = []

            let ipv4RouteIterator = options.getInet4RouteAddress()!
            if ipv4RouteIterator.hasNext() {
                while ipv4RouteIterator.hasNext() {
                    let prefix = ipv4RouteIterator.next()!
                    ipv4Routes.append(
                        NEIPv4Route(
                            destinationAddress: prefix.address(),
                            subnetMask: prefix.mask()
                        )
                    )
                }
            } else if prefs.autoRouteUseSubRangesByDefault {
                ipv4Routes.append(NEIPv4Route(destinationAddress: "1.0.0.0", subnetMask: "255.0.0.0"))
                ipv4Routes.append(NEIPv4Route(destinationAddress: "2.0.0.0", subnetMask: "254.0.0.0"))
                ipv4Routes.append(NEIPv4Route(destinationAddress: "4.0.0.0", subnetMask: "252.0.0.0"))
                ipv4Routes.append(NEIPv4Route(destinationAddress: "8.0.0.0", subnetMask: "248.0.0.0"))
                ipv4Routes.append(NEIPv4Route(destinationAddress: "16.0.0.0", subnetMask: "240.0.0.0"))
                ipv4Routes.append(NEIPv4Route(destinationAddress: "32.0.0.0", subnetMask: "224.0.0.0"))
                ipv4Routes.append(NEIPv4Route(destinationAddress: "64.0.0.0", subnetMask: "192.0.0.0"))
                ipv4Routes.append(NEIPv4Route(destinationAddress: "128.0.0.0", subnetMask: "128.0.0.0"))
            } else {
                ipv4Routes.append(.default())
            }

            let ipv4ExcludeIterator = options.getInet4RouteExcludeAddress()!
            while ipv4ExcludeIterator.hasNext() {
                let prefix = ipv4ExcludeIterator.next()!
                ipv4ExcludedRoutes.append(
                    NEIPv4Route(
                        destinationAddress: prefix.address(),
                        subnetMask: prefix.mask()
                    )
                )
            }

            if prefs.excludeDefaultRoute, !ipv4Routes.isEmpty {
                ipv4ExcludedRoutes.append(
                    NEIPv4Route(destinationAddress: "0.0.0.0", subnetMask: "255.255.255.254")
                )
            }

            if prefs.excludeAPNsRoute, !ipv4Routes.isEmpty {
                ipv4ExcludedRoutes.append(
                    NEIPv4Route(destinationAddress: "17.0.0.0", subnetMask: "255.0.0.0")
                )
            }

            ipv4Settings.includedRoutes = ipv4Routes
            ipv4Settings.excludedRoutes = ipv4ExcludedRoutes
            settings.ipv4Settings = ipv4Settings

            let hasDefaultIPv4Route = ipv4Routes.contains {
                $0.destinationAddress == "0.0.0.0" && $0.destinationSubnetMask == "0.0.0.0"
            }
            if !hasDefaultIPv4Route {
                dnsSettings.matchDomains = [""]
                dnsSettings.matchDomainsNoSearch = true
            }
        }

        if options.isHTTPProxyEnabled() {
            let proxySettings = NEProxySettings()
            let proxyServer = NEProxyServer(
                address: options.getHTTPProxyServer(),
                port: Int(options.getHTTPProxyServerPort())
            )
            proxySettings.httpServer = proxyServer
            proxySettings.httpsServer = proxyServer
            proxySettings.httpEnabled = prefs.systemProxyEnabled
            proxySettings.httpsEnabled = prefs.systemProxyEnabled

            var bypassDomains: [String] = []
            let bypassIterator = options.getHTTPProxyBypassDomain()!
            while bypassIterator.hasNext() {
                bypassDomains.append(bypassIterator.next())
            }
            if prefs.excludeAPNsRoute, !bypassDomains.contains("push.apple.com") {
                bypassDomains.append("push.apple.com")
            }
            if !bypassDomains.isEmpty {
                proxySettings.exceptionList = bypassDomains
            }

            var matchDomains: [String] = []
            let matchIterator = options.getHTTPProxyMatchDomain()!
            while matchIterator.hasNext() {
                matchDomains.append(matchIterator.next())
            }
            if !matchDomains.isEmpty {
                proxySettings.matchDomains = matchDomains
            }

            settings.proxySettings = proxySettings
        }

        networkSettings = settings
        try await tunnel.setTunnelNetworkSettings(settings)

        if let tunFd = tunnel.packetFlow.value(forKeyPath: "socket.fileDescriptor") as? Int32 {
            tunFdPointer.pointee = tunFd
            return
        }

        let tunnelFd = LibboxGetTunnelFileDescriptor()
        if tunnelFd == -1 {
            throw NSError(domain: "ExtensionPlatformInterface", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "Missing tunnel file descriptor.",
            ])
        }

        tunFdPointer.pointee = tunnelFd
    }

    func usePlatformAutoDetectControl() -> Bool {
        false
    }

    func autoDetectControl(_ fd: Int32) throws {}

    func findConnectionOwner(
        _ ipProtocol: Int32,
        sourceAddress: String?,
        sourcePort: Int32,
        destinationAddress: String?,
        destinationPort: Int32
    ) throws -> LibboxConnectionOwner {
        throw NSError(domain: "ExtensionPlatformInterface", code: 0, userInfo: [
            NSLocalizedDescriptionKey: "Connection owner lookup is not implemented.",
        ])
    }

    func useProcFS() -> Bool {
        false
    }

    func writeLog(_ message: String?) {
        guard let message else {
            return
        }

        tunnel.writeMessage(message)
    }

    func startDefaultInterfaceMonitor(_ listener: LibboxInterfaceUpdateListenerProtocol?) throws {
        guard let listener else {
            return
        }

        let monitor = Network.NWPathMonitor()
        nwMonitor = monitor
        let semaphore = DispatchSemaphore(value: 0)

        monitor.pathUpdateHandler = { [weak self] path in
            self?.updateDefaultInterface(listener, path: path)
            semaphore.signal()
            monitor.pathUpdateHandler = { [weak self] path in
                self?.updateDefaultInterface(listener, path: path)
            }
        }

        monitor.start(queue: DispatchQueue.global())
        semaphore.wait()
    }

    private func updateDefaultInterface(_ listener: LibboxInterfaceUpdateListenerProtocol, path: Network.NWPath) {
        guard path.status != .unsatisfied, let interface = path.availableInterfaces.first else {
            listener.updateDefaultInterface("", interfaceIndex: -1, isExpensive: false, isConstrained: false)
            return
        }

        listener.updateDefaultInterface(
            interface.name,
            interfaceIndex: Int32(interface.index),
            isExpensive: path.isExpensive,
            isConstrained: path.isConstrained
        )
    }

    func closeDefaultInterfaceMonitor(_ listener: LibboxInterfaceUpdateListenerProtocol?) throws {
        nwMonitor?.cancel()
        nwMonitor = nil
    }

    func getInterfaces() throws -> LibboxNetworkInterfaceIteratorProtocol {
        guard let nwMonitor else {
            throw NSError(domain: "ExtensionPlatformInterface", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "Default interface monitor has not started.",
            ])
        }

        let path = nwMonitor.currentPath
        guard path.status != .unsatisfied else {
            return NetworkInterfaceArray([])
        }

        let interfaces = path.availableInterfaces.map { interface -> LibboxNetworkInterface in
            let result = LibboxNetworkInterface()
            result.name = interface.name
            result.index = Int32(interface.index)
            switch interface.type {
            case .wifi:
                result.type = LibboxInterfaceTypeWIFI
            case .cellular:
                result.type = LibboxInterfaceTypeCellular
            case .wiredEthernet:
                result.type = LibboxInterfaceTypeEthernet
            default:
                result.type = LibboxInterfaceTypeOther
            }
            return result
        }

        return NetworkInterfaceArray(interfaces)
    }

    func underNetworkExtension() -> Bool {
        true
    }

    func includeAllNetworks() -> Bool {
        tunnel.overridePreferences?.includeAllNetworks ?? false
    }

    func clearDNSCache() {
        guard let networkSettings else {
            return
        }

        runBlocking {
            self.tunnel.reasserting = true
            defer { self.tunnel.reasserting = false }

            await withCheckedContinuation { continuation in
                self.tunnel.setTunnelNetworkSettings(nil) { _ in
                    continuation.resume()
                }
            }

            await withCheckedContinuation { continuation in
                self.tunnel.setTunnelNetworkSettings(networkSettings) { _ in
                    continuation.resume()
                }
            }
        }
    }

    func readWIFIState() -> LibboxWIFIState? {
        nil
    }

    func readWIFISSID() -> String? {
        nil
    }

    func serviceStop() throws {
        tunnel.stopService()
    }

    func serviceReload() throws {
        try runBlocking {
            try await self.tunnel.reloadService()
        }
    }

    func getSystemProxyStatus() throws -> LibboxSystemProxyStatus {
        let status = LibboxSystemProxyStatus()
        guard
            let proxySettings = networkSettings?.proxySettings,
            proxySettings.httpServer != nil
        else {
            return status
        }

        status.available = true
        status.enabled = proxySettings.httpEnabled
        return status
    }

    func setSystemProxyEnabled(_ isEnabled: Bool) throws {
        guard let networkSettings, let proxySettings = networkSettings.proxySettings else {
            return
        }

        proxySettings.httpEnabled = isEnabled
        proxySettings.httpsEnabled = isEnabled
        self.networkSettings?.proxySettings = proxySettings

        try runBlocking {
            try await self.tunnel.setTunnelNetworkSettings(networkSettings)
        }
    }

    func triggerNativeCrash() throws {
        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(200)) {
            fatalError("debug native crash")
        }
    }

    func writeDebugMessage(_ message: String?) {
        guard let message else {
            return
        }

        Self.logger.debug("\(message, privacy: .public)")
    }

    func send(_ notification: LibboxNotification?) throws {
        guard let notification else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.subtitle = notification.subtitle
        content.body = notification.body
        content.interruptionLevel = .active

        let request = UNNotificationRequest(
            identifier: notification.identifier,
            content: content,
            trigger: nil
        )

        try runBlocking {
            try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert])
            try await UNUserNotificationCenter.current().add(request)
        }
    }

    func startNeighborMonitor(_ listener: LibboxNeighborUpdateListenerProtocol?) throws {}

    func registerMyInterface(_ name: String?) {}

    func closeNeighborMonitor(_ listener: LibboxNeighborUpdateListenerProtocol?) throws {}

    func localDNSTransport() -> (any LibboxLocalDNSTransportProtocol)? {
        nil
    }

    func systemCertificates() -> (any LibboxStringIteratorProtocol)? {
        nil
    }

    func reset() {
        nwMonitor?.cancel()
        nwMonitor = nil
        networkSettings = nil
    }
}

private final class NetworkInterfaceArray: NSObject, LibboxNetworkInterfaceIteratorProtocol {
    private var iterator: IndexingIterator<[LibboxNetworkInterface]>
    private var nextValue: LibboxNetworkInterface?

    init(_ values: [LibboxNetworkInterface]) {
        iterator = values.makeIterator()
    }

    func hasNext() -> Bool {
        nextValue = iterator.next()
        return nextValue != nil
    }

    func next() -> LibboxNetworkInterface? {
        nextValue
    }
}
