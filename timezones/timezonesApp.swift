import SwiftUI
import AppKit
import Combine

@main
struct timezonesApp: App {
    @StateObject private var store: TimeStore
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        let s = TimeStore()
        _store = StateObject(wrappedValue: s)
        AppDelegate.pendingStore = s
        if let inst = AppDelegate.instance {
            inst.store = s
        }
    }

    var body: some Scene {
        Window("Timezones", id: "main") {
            VStack(spacing: 0) {
                ContentView(store: store)
                OpenWindowInjector()
                    .frame(width: 0, height: 0)
            }
            .frame(minWidth: 440, minHeight: 200)
        }
        .windowResizability(.contentSize)

        Window("Settings", id: "settings") {
            VStack(spacing: 0) {
                SettingsView(store: store)
                OpenWindowInjector()
                    .frame(width: 0, height: 0)
            }
        }
        .windowResizability(.contentSize)
    }
}

struct OpenWindowInjector: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                AppDelegate.instance?.openWindowAction = { id in
                    openWindow(id: id)
                }
            }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    static var instance: AppDelegate?
    static var pendingStore: TimeStore?

    var store: TimeStore?
    var openWindowAction: ((String) -> Void)?

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var cancellables = Set<AnyCancellable>()
    private var windowCloseObserver: NSObjectProtocol?

    override init() {
        super.init()
        AppDelegate.instance = self
        if store == nil {
            store = AppDelegate.pendingStore
        }
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Prevent macOS from restoring Settings window from previous session.
        // This is what made Settings persist on screen after relaunch.
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
        closeLaunchWindowsNow()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        // Disable secure state restoration so detached windows do not come back.
        return false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if store == nil {
            store = AppDelegate.pendingStore
        }
        guard let store else { return }
        setupStatusItem(store: store)
        setupPopover(store: store)
        observeMenuBarText(store: store)
        observeWindowClose()
        closeDetachedWindowAtLaunch()
    }

    private func setupStatusItem(store: TimeStore) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.isVisible = true
        if let button = item.button {
            button.title = store.menuBarText
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
            button.target = self
            button.action = #selector(handleStatusClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "Timezones - click for times, right-click for Settings / Quit"
        }
        self.statusItem = item
    }

    private func setupPopover(store: TimeStore) {
        let p = NSPopover()
        p.contentSize = NSSize(width: 430, height: 480)
        p.behavior = .transient
        p.animates = true
        p.delegate = self
        p.contentViewController = NSHostingController(rootView: ContentView(store: store))
        self.popover = p
    }

    private func observeWindowClose() {
        windowCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let window = note.object as? NSWindow else { return }
            if window.title == "Timezones" {
                self?.store?.goLive()
            }
        }
    }

    func popoverDidClose(_ notification: Notification) {
        store?.goLive()
    }

    private func closeLaunchWindowsNow() {
        for window in NSApp.windows where window.title == "Timezones" || window.title == "Settings" {
            window.alphaValue = 0
            window.orderOut(nil)
            window.close()
        }
    }

    private func closeDetachedWindowAtLaunch() {
        // The Window(id: main) Scene opens automatically on launch.
        // We want menu-bar popover by default, detached only on demand.
        // Hide with alpha 0 + orderOut to avoid animated flicker/blip.
        func closeLaunchWindows() {
            for window in NSApp.windows where window.title == "Timezones" || window.title == "Settings" {
                window.alphaValue = 0
                window.orderOut(nil)
                window.close()
            }
        }
        closeLaunchWindows()
        DispatchQueue.main.async {
            closeLaunchWindows()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            closeLaunchWindows()
        }
    }

    private func observeMenuBarText(store: TimeStore) {
        store.$liveNow
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateTitle()
            }
            .store(in: &cancellables)
        updateTitle()
    }

    private func updateTitle() {
        guard let store, let button = statusItem?.button else { return }
        let text = store.menuBarText
        if button.title != text {
            button.title = text
        }
    }

    @objc private func handleStatusClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            togglePopover()
            return
        }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showContextMenu(for: sender)
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = statusItem?.button, let popover else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func showContextMenu(for button: NSStatusBarButton) {
        popover?.performClose(nil)
        let menu = makeContextMenu()
        if let event = NSApp.currentEvent {
            NSMenu.popUpContextMenu(menu, with: event, for: button)
        } else {
            statusItem?.menu = menu
            button.performClick(nil)
            statusItem?.menu = nil
        }
    }

    private func makeContextMenu() -> NSMenu {
        let menu = NSMenu()
        let center = NSMutableParagraphStyle()
        center.alignment = .center

        let titleItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        titleItem.attributedTitle = NSAttributedString(
            string: "TimeZones",
            attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                .paragraphStyle: center
            ]
        )
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        let subItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        subItem.attributedTitle = NSAttributedString(
            string: "by GarrigAI LLC",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: center
            ]
        )
        subItem.isEnabled = false
        menu.addItem(subItem)

        menu.addItem(NSMenuItem.separator())

        let detachedItem = NSMenuItem(title: "New Window", action: #selector(openDetachedWindow), keyEquivalent: "")
        detachedItem.target = self
        detachedItem.image = NSImage(systemSymbolName: "macwindow", accessibilityDescription: "New Window")
        menu.addItem(detachedItem)

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        settingsItem.image = NSImage(systemSymbolName: "gear", accessibilityDescription: "Settings")
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Timezones", action: #selector(quitApp), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    @objc private func openDetachedWindow() {
        if let action = openWindowAction {
            action("main")
            NSApp.activate(ignoringOtherApps: true)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            for window in NSApp.windows where window.title == "Timezones" {
                window.makeKeyAndOrderFront(nil)
                return
            }
        }
    }

    @objc private func openSettings() {
        if let action = openWindowAction {
            action("settings")
            NSApp.activate(ignoringOtherApps: true)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            for window in NSApp.windows where window.title == "Settings" {
                window.makeKeyAndOrderFront(nil)
                return
            }
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
