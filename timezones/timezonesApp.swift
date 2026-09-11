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
        field.textColor = .labelColor
        field.alignment = .center
        field.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        field.lineBreakMode = .byClipping
        field.cell?.truncatesLastVisibleLine = false
        field.setContentHuggingPriority(.required, for: .horizontal)
        field.setContentHuggingPriority(.required, for: .vertical)
        field.setContentCompressionResistancePriority(.required, for: .horizontal)
        field.setContentCompressionResistancePriority(.required, for: .vertical)
        field.toolTip = "Timezones - right-click for Settings / Quit"
        field.onSettings = onSettings
        field.onQuit = onQuit
        field.menu = makeMenu(for: field)
        field.sizeToFit()
        field.invalidateIntrinsicContentSize()
        return field
    }

    func updateNSView(_ nsView: MenuBarTextField, context: Context) {
        nsView.onSettings = onSettings
        nsView.onQuit = onQuit
        if nsView.stringValue != text {
            nsView.stringValue = text
            nsView.sizeToFit()
            nsView.invalidateIntrinsicContentSize()
            nsView.needsDisplay = true
        }
        if nsView.menu == nil {
            nsView.menu = makeMenu(for: nsView)
        }
    }

    private func makeMenu(for field: MenuBarTextField) -> NSMenu {
        let menu = NSMenu()
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(MenuBarTextField.handleSettings), keyEquivalent: "")
        settingsItem.target = field
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit Timezones", action: #selector(MenuBarTextField.handleQuit), keyEquivalent: "")
        quitItem.target = field
        menu.addItem(quitItem)
        return menu
    }
}

final class MenuBarTextField: NSTextField {
    var onSettings: () -> Void = {}
    var onQuit: () -> Void = {}

    override var intrinsicContentSize: NSSize {
        // Compute from current string so M/d HH:mm never clips to zero width.
        let str = stringValue as NSString
        let fontToUse = font ?? NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [.font: fontToUse]
        let size = str.size(withAttributes: attrs)
        // Pad a little so last digit is never clipped.
        return NSSize(width: ceil(size.width) + 8, height: max(22, ceil(size.height) + 4))
    }

    override func rightMouseDown(with event: NSEvent) {
        if let menu = menu {
            NSMenu.popUpContextMenu(menu, with: event, for: self)
        } else {
            super.rightMouseDown(with: event)
        }
    }

    override func mouseDown(with event: NSEvent) {
        // Ctrl-click should behave as right-click.
        if event.modifierFlags.contains(.control) {
            rightMouseDown(with: event)
            return
        }
        // Leave left-click alone so MenuBarExtra opens the window.
        super.mouseDown(with: event)
    }

    @objc func handleSettings(_ sender: Any?) {
        onSettings()
    }

    @objc func handleQuit(_ sender: Any?) {
        onQuit()
    }
}
