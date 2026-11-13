// Entry point. Starts Stagehand as a menu bar–only app and hands control to AppDelegate.
import AppKit

// Create the app, attach the delegate, and hide the Dock icon
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)

// Run the event loop until the user quits
app.run()
