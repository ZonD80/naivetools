import NetworkExtension
import SwiftUI

private struct ShareSheetPayload: Identifiable {
    let id = UUID()
    let urlString: String
}

struct ContentView: View {
    @EnvironmentObject private var connectionStore: ConnectionStore
    @Environment(\.openURL) private var openURL
    @StateObject private var appdbVersionChecker = AppdbVersionUpdateChecker()
    @State private var showingAlert = false
    @State private var showingQRScanner = false
    @State private var shareSheetPayload: ShareSheetPayload?

    var body: some View {
        NavigationStack {
            Form {
                if appdbVersionChecker.isNewerVersionAvailable, let version = appdbVersionChecker.storeVersion {
                    Section {
                        Button {
                            openURL(AppConfiguration.appdbAppDetailsURL)
                        } label: {
                            HStack(alignment: .center, spacing: 10) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                Text(L10n.newVersionOnAppdbBanner(version: version))
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(L10n.tr("Opens appdb in Safari"))
                    }
                    .listRowBackground(Color.accentColor.opacity(0.12))
                }

                Section(L10n.tr("Configs")) {
                    Picker(L10n.tr("Saved Config"), selection: $connectionStore.selectedProfileID) {
                        ForEach(connectionStore.profiles) { savedProfile in
                            Text(savedProfile.displayName).tag(savedProfile.id)
                        }
                    }

                    HStack(spacing: 0) {
                        Button {
                            showingQRScanner = true
                        } label: {
                            Image(systemName: "qrcode.viewfinder")
                        }
                        .buttonStyle(.borderless)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(L10n.tr("Scan QR Code"))

                        Button(action: connectionStore.createProfile) {
                            Image(systemName: "plus.circle")
                        }
                        .buttonStyle(.borderless)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(L10n.tr("New"))

                        Button(action: connectionStore.duplicateSelectedProfile) {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(L10n.tr("Duplicate"))

                        Button(role: .destructive, action: connectionStore.deleteSelectedProfile) {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .frame(maxWidth: .infinity)
                        .disabled(!connectionStore.canDeleteProfile)
                        .accessibilityLabel(L10n.tr("Delete"))

                        Button {
                            if let url = NaiveQRCodeParser.shareLinkString(for: connectionStore.profile) {
                                shareSheetPayload = ShareSheetPayload(urlString: url)
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .buttonStyle(.borderless)
                        .frame(maxWidth: .infinity)
                        .disabled(NaiveQRCodeParser.shareLinkString(for: connectionStore.profile) == nil)
                        .accessibilityLabel(L10n.tr("Share"))
                    }
                }

                Section(L10n.tr("Server")) {
                    TextField(L10n.tr("Name"), text: $connectionStore.profile.name)

                    TextField(L10n.tr("Host"), text: $connectionStore.profile.host)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)

                    Picker(L10n.tr("Type"), selection: $connectionStore.profile.type) {
                        ForEach(NaiveProxyType.allCases) { proxyType in
                            Text(proxyType.rawValue).tag(proxyType)
                        }
                    }
                    .pickerStyle(.segmented)

                    TextField(L10n.tr("Port"), text: $connectionStore.profile.port)
                        .keyboardType(.numberPad)

                    TextField(L10n.tr("User"), text: $connectionStore.profile.user)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    SecureField(L10n.tr("Password"), text: $connectionStore.profile.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section(L10n.tr("Status")) {
                    HStack {
                        Text(L10n.tr("VPN"))
                        Spacer()
                        Text(connectionStore.statusText)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text(L10n.tr("IP"))
                        Spacer()
                        Text(connectionStore.publicIPAddress)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }

                    if connectionStore.isBusy {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }

                Section {
                    Button(action: connectionStore.toggleConnection) {
                        Image(systemName: connectionStore.connectionToggleIconName)
                            .font(.title2)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(connectionStore.isBusy)
                    .accessibilityLabel(connectionStore.actionTitle)
                }
            }
            .navigationTitle(AppConfiguration.appName)
            .task {
                await appdbVersionChecker.refreshIfNeeded()
            }
            .onReceive(connectionStore.$errorMessage) { message in
                showingAlert = message != nil
            }
            .alert(L10n.tr("Connection Error"), isPresented: $showingAlert, actions: {
                Button(L10n.tr("OK"), role: .cancel) {
                    connectionStore.errorMessage = nil
                }
            }, message: {
                Text(connectionStore.errorMessage ?? L10n.tr("Unknown error."))
            })
            .sheet(isPresented: $showingQRScanner) {
                QRCodeScannerSheet(
                    onCodeScanned: { payload in
                        do {
                            try connectionStore.importProfile(fromQRCodePayload: payload)
                        } catch {
                            connectionStore.errorMessage = error.localizedDescription
                        }
                    },
                    onFailure: { message in
                        connectionStore.errorMessage = message
                    }
                )
            }
            .sheet(item: $shareSheetPayload) { payload in
                ShareProfileSheet(shareURL: payload.urlString)
            }
        }
    }
}
