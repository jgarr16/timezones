import SwiftUI
import AppKit

@main
struct timezonesApp: App {
    @StateObject private var store = TimeStore()

    var body: some Scene {
        MenuBarExtra {
            ContentView(store: store)
        } label: {
            Text(store.localHHmm)
                .font(.system(size: 13).monospacedDigit())
        }
        .menuBarExtraStyle(.window)

        Window("Timezones", id: "main") {
            ContentView(store: store)
                .frame(minWidth: 360, minHeight: 200)
        }
        .windowResizability(.contentSize)

        Window("Settings", id: "settings") {
            SettingsView(store: store)
                .frame(minWidth: 280, minHeight: 320)
        }
        .windowResizability(.contentSize)
    }
}
