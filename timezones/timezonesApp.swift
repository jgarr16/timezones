import SwiftUI
import AppKit

@main
struct timezonesApp: App {
    @StateObject private var store = TimeStore()

    var body: some Scene {
        MenuBarExtra {
            ContentView(store: store)
        } label: {
            MenuBarLabelView(store: store)
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

struct MenuBarLabelView: View {
    @ObservedObject var store: TimeStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(store.menuBarText)
            .font(.system(size: 13).monospacedDigit())
            .contextMenu {
                Button("Settings...") {
                    openWindow(id: "settings")
                    NSApp.activate(ignoringOtherApps: true)
                }
                Divider()
                Button("Quit Timezones") {
                    NSApplication.shared.terminate(nil)
                }
            }
    }
}
