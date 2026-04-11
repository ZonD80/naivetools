import NetworkExtension
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var connectionStore: ConnectionStore
    @State private var showingAlert = false
    @State private var showingQRScanner = false

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.tr("Configs")) {
                    Picker(L10n.tr("Saved Config"), selection: $connectionStore.selectedProfileID) {
                        ForEach(connectionStore.profiles) { savedProfile in
                            Text(savedProfile.displayName).tag(savedProfile.id)
                        }
                    }

                    HStack {
                        Button(L10n.tr("New"), action: connectionStore.createProfile)
                        Spacer()
                        Button(L10n.tr("Duplicate"), action: connectionStore.duplicateSelectedProfile)
                        Spacer()
                        Button(L10n.tr("Delete"), role: .destructive, action: connectionStore.deleteSelectedProfile)
                            .disabled(!connectionStore.canDeleteProfile)
                    }

                    Button {
                        showingQRScanner = true
                    } label: {
                        Label(L10n.tr("Scan QR Code"), systemImage: "qrcode.viewfinder")
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
                        Text(connectionStore.actionTitle)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(connectionStore.isBusy)
                }
            }
            .navigationTitle(AppConfiguration.appName)
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
        }
    }
}
