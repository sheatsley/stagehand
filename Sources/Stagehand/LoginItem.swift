// Turns "Open at Login" on and off using macOS's built-in login item service.
import ServiceManagement

enum LoginItem {
    /// True if Stagehand is registered to open at login.
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Registers or unregisters Stagehand as a login item. The item then shows
    /// up in System Settings → General → Login Items. Throws if macOS refuses.
    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
