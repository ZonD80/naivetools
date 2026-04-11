import SwiftUI

@main
struct NaiveVPNApp: App {
    @StateObject private var connectionStore = ConnectionStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectionStore)
        }
    }
}
