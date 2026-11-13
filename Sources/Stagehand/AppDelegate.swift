// Owns the menu bar item, its menu, and the About window.
import AppKit
import SwiftUI

/// Sets up the menu bar item at launch, reconnects Sidecar at launch and on
/// every screen unlock, and rebuilds the menu each time it opens so the status
/// lines are current. Takes no inputs; macOS calls these methods itself.
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private let sidecar = SidecarController()
    private var aboutWindow: NSWindow?

    /// Runs once at launch: creates the menu bar item, starts the first Sidecar
    /// connection, and subscribes to screen-unlock notifications.
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the menu bar item with a template icon so macOS picks its color
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = MenuBarIcon.make()
        menu.delegate = self
        statusItem.menu = menu

        // Connect at launch, which covers logging in when Open at Login is on
        sidecar.reconnect(after: 3)

        // Reconnect every time the screen is unlocked
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(screenDidUnlock),
            name: Notification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )
    }

    /// Called by macOS right after the user unlocks the screen. Waits a moment
    /// so Bluetooth/Wi-Fi discovery can find the iPad, then reconnects.
    @objc private func screenDidUnlock(_ notification: Notification) {
        sidecar.reconnect(after: 2)
    }

    // MARK: - Menu

    /// Called by AppKit just before the menu opens. Rebuilds every item so the
    /// status lines reflect the latest Sidecar attempt and stage snapshot.
    func menuNeedsUpdate(_ menu: NSMenu) {
        // Start from an empty menu
        menu.removeAllItems()

        // Sidecar section: status lines, then the reconnect action
        addStatusLines(sidecar.statusLines())
        addAction("Reconnect Sidecar", #selector(reconnectClicked), enabled: !sidecar.isConnecting)
        menu.addItem(.separator())

        // Stage Manager section: status lines, then save and restore
        addStatusLines(StageManager.statusLines())
        addAction("Save Stages", #selector(saveStagesClicked))
        addAction("Restore Stages", #selector(restoreStagesClicked), enabled: StageManager.hasSnapshot)
        menu.addItem(.separator())

        // Open at Login toggle, checked when enabled
        addAction("Open at Login", #selector(toggleOpenAtLogin)).state = LoginItem.isEnabled ? .on : .off
        menu.addItem(.separator())

        // Standard About and Quit items
        addAction("About \(AppInfo.current.name)", #selector(showAbout))
        menu.addItem(NSMenuItem(title: "Quit \(AppInfo.current.name)",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
    }

    /// Adds gray, unclickable status lines, like Time Machine's "Latest Backup" header.
    private func addStatusLines(_ lines: [(text: String, toolTip: String?)]) {
        for line in lines {
            let item = NSMenuItem(title: line.text, action: nil, keyEquivalent: "")
            item.isEnabled = false
            item.toolTip = line.toolTip
            menu.addItem(item)
        }
    }

    /// Adds a clickable item that calls `action` on this object, and returns it
    /// so the caller can adjust it further (for example, add a checkmark).
    @discardableResult
    private func addAction(_ title: String, _ action: Selector, enabled: Bool = true) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.isEnabled = enabled
        menu.addItem(item)
        return item
    }

    // MARK: - Actions

    /// "Reconnect Sidecar": starts a connection attempt right away.
    @objc private func reconnectClicked() {
        sidecar.reconnect()
    }

    /// "Save Stages": snapshots Stage Manager's current state, replacing the previous snapshot.
    @objc private func saveStagesClicked() {
        do {
            try StageManager.save()
        } catch {
            showError("Couldn’t Save Stages", error)
        }
    }

    /// "Restore Stages": puts the saved snapshot back and restarts Stage Manager.
    @objc private func restoreStagesClicked() {
        do {
            try StageManager.restore()
        } catch {
            showError("Couldn’t Restore Stages", error)
        }
    }

    /// "Open at Login": flips the login item on or off.
    @objc private func toggleOpenAtLogin() {
        do {
            try LoginItem.setEnabled(!LoginItem.isEnabled)
        } catch {
            showError("Couldn’t Change Open at Login", error)
        }
    }

    /// "About": creates the About window the first time, then brings it to the
    /// front, since a menu bar app is never frontmost on its own.
    @objc private func showAbout() {
        // Build the window once and keep it around for later clicks
        if aboutWindow == nil {
            let window = NSWindow(
                contentRect: .zero,
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.contentViewController = NSHostingController(rootView: AboutView())
            window.center()
            aboutWindow = window
        }

        // Bring Stagehand forward and show the window
        NSApp.activate()
        aboutWindow?.makeKeyAndOrderFront(nil)
    }

    /// Shows a standard warning alert with the error's description.
    private func showError(_ title: String, _ error: Error) {
        NSApp.activate()
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }
}
