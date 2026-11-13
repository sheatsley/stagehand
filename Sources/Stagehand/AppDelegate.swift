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
        // Start the log and record what's running
        Log.start()
        let info = AppInfo.current
        Log.write("app", "Launched \(info.name) \(info.version) (\(info.commit)) on macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")

        // Create the menu bar item with a template icon so macOS picks its color
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = MenuBarIcon.make()
        menu.delegate = self
        statusItem.menu = menu

        // Restore the session at launch, which covers logging in when Open at Login is on.
        // Wait longer than after an unlock, since apps are still opening their windows.
        restoreSession(after: 5)

        // Restore the session every time the screen is unlocked
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(sessionDidResume),
            name: Notification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )

        // ...and when switching back to this account with Fast User Switching
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(sessionDidResume),
            name: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil
        )

        // Log (but don't act on) lock, sleep, and wake, for context when debugging
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(logEvent),
            name: Notification.Name("com.apple.screenIsLocked"), object: nil
        )
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.didWakeNotification] {
            NSWorkspace.shared.notificationCenter.addObserver(
                self, selector: #selector(logEvent), name: name, object: nil
            )
        }
    }

    /// Called by macOS after an unlock or a switch back to this account. Waits
    /// a moment so Bluetooth/Wi-Fi discovery can find the iPad, then restores.
    @objc private func sessionDidResume(_ notification: Notification) {
        Log.write("event", notification.name.rawValue)
        restoreSession(after: 2)
    }

    /// Records events Stagehand doesn't act on (lock, sleep, wake), so the log
    /// shows the full sequence when something goes wrong.
    @objc private func logEvent(_ notification: Notification) {
        Log.write("event", notification.name.rawValue)
    }

    /// Reconnects Sidecar, then, once that finishes and the display setup has
    /// settled, restores the saved stages. Stages are restored even if Sidecar
    /// fails, since the main display's stages still matter. Does nothing extra
    /// if a reconnect is already running, so overlapping triggers restore once.
    private func restoreSession(after delay: TimeInterval) {
        Log.write("session", "Restoring session in \(Int(delay))s")
        sidecar.reconnect(after: delay) {
            // Record which displays macOS sees, to help diagnose Sidecar issues
            Log.write("display", "Screens: \(NSScreen.screens.map(\.localizedName))")

            // Give macOS a moment to finish arranging displays before restoring
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.restoreStagesAutomatically()
            }
        }
    }

    /// Restores the saved stages without an alert, since nobody clicked
    /// anything. Skips if nothing is saved. A failure appears in the menu.
    private func restoreStagesAutomatically() {
        guard StageManager.hasSnapshot else {
            Log.write("stages", "No saved stages; skipping automatic restore")
            return
        }
        try? StageManager.restore()  // StageManager logs the outcome
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
        Log.write("menu", "Reconnect Sidecar clicked")
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
            Log.write("login", "Open at Login is now \(LoginItem.isEnabled ? "on" : "off")")
        } catch {
            Log.write("login", "Couldn’t change Open at Login: \(Log.describe(error))")
            showError("Couldn’t Change Open at Login", error)
        }
    }

    /// "About": creates the About window the first time, then puts it in front
    /// of every other window and gives it keyboard focus, without activating
    /// Stagehand. Not activating the app is what keeps Stage Manager from
    /// treating the window as a new stage and sweeping your other windows
    /// aside, which matches how About This Mac behaves.
    @objc private func showAbout() {
        // Build the window once and keep it around for later clicks
        if aboutWindow == nil {
            let panel = AboutPanel(
                contentRect: .zero,
                styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.titlebarAppearsTransparent = true
            panel.titleVisibility = .hidden
            panel.isMovableByWindowBackground = true
            panel.isReleasedWhenClosed = false
            panel.hidesOnDeactivate = false
            panel.contentViewController = NSHostingController(rootView: AboutView())
            panel.center()
            aboutWindow = panel
        }

        // Put the window in front and focus it without activating the app
        aboutWindow?.orderFrontRegardless()
        aboutWindow?.makeKey()
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

/// The About window. A non-activating panel can take keyboard focus without
/// making Stagehand the active app. Since a menu bar app has no menu bar of
/// its own to supply ⌘W, this panel handles ⌘W and Esc itself.
final class AboutPanel: NSPanel {
    /// Closes the panel when the user presses Esc.
    override func cancelOperation(_ sender: Any?) {
        close()
    }

    /// Closes the panel on ⌘W; passes every other shortcut along.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
           event.charactersIgnoringModifiers == "w" {
            close()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
