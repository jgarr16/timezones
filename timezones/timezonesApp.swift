import SwiftUI
import AppKit

@main
struct timezonesApp: App {
    var body: some Scene {
        Window("Timezones", id: "main") {
            ContentView()
                .frame(minWidth: 760, minHeight: 520)
        }
        .windowResizability(.contentSize)

        MenuBarExtra("Timezones", systemImage: "clock") {
            MenuBarView()
        }
    }
}

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open Timezones") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut("o")

        Divider()

        Button("Quit Timezones") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
