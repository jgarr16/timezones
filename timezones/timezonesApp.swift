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
                .frame(minWidth: 440, minHeight: 200)
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
        MenuBarLabelRepresentable(
            text: store.menuBarText,
            onSettings: {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            },
            onQuit: {
                NSApplication.shared.terminate(nil)
            }
        )
    }
}

struct MenuBarLabelRepresentable: NSViewRepresentable {
    let text: String
    let onSettings: () -> Void
    let onQuit: () -> Void

    func makeNSView(context: Context) -> MenuBarTextField {
        let field = MenuBarTextField(labelWithString: text)
        field.isEditable = false
        field.isSelectable = false
        field.isBordered = false
        field.backgroundColor = .clear
        field.alignment = .center
        field.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        field.onSettings = onSettings
        field.onQuit = onQuit
        field.menu = makeMenu(for: field)
        return field
    }

    func updateNSView(_ nsView: MenuBarTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.onSettings = onSettings
        nsView.onQuit = onQuit
        if nsView.menu == nil {
            nsView.menu = makeMenu(for: nsView)
        }
    }

    private func makeMenu(for field: MenuBarTextField) -> NSMenu {
        let menu = NSMenu()
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(MenuBarTextField.handleSettings), keyEquivalent: ",")
        settingsItem.target = field
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit Timezones", action: #selector(MenuBarTextField.handleQuit), keyEquivalent: "q")
        quitItem.target = field
        menu.addItem(quitItem)
        return menu
    }
}

final class MenuBarTextField: NSTextField {
    var onSettings: () -> Void = {}
    var onQuit: () -> Void = {}

    @objc func handleSettings(_ sender: Any?) {
        onSettings()
    }

    @objc func handleQuit(_ sender: Any?) {
        onQuit()
    }
}
