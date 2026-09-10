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
                .frame(minWidth: 250, minHeight: 180)
        }
        .windowResizability(.contentSize)
    }
}
