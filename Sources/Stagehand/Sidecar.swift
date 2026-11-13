// Talks to Apple's private SidecarCore framework and tracks connection status for the menu.
import Foundation

/// Errors Stagehand reports when a Sidecar connection can't be made.
enum SidecarError: LocalizedError {
    case frameworkUnavailable
    case noDevices
    case deviceNotFound(String)

    var errorDescription: String? {
        switch self {
        case .frameworkUnavailable:
            return "SidecarCore isn't available on this version of macOS."
        case .noDevices:
            return "No iPad is reachable for Sidecar."
        case .deviceNotFound(let name):
            return "“\(name)” isn't reachable for Sidecar."
        }
    }
}

/// Thin wrapper around the private SidecarCore framework. The framework is
/// loaded at runtime, so if Apple removes or renames it, Stagehand still launches
/// and reports an error instead of crashing. These selectors match the ones the
/// open-source SidecarLauncher tool uses.
enum SidecarCore {
    /// The shared SidecarDisplayManager instance, or nil if the framework
    /// couldn't be loaded. Evaluated once, on first use.
    private static let manager: NSObject? = {
        // Load the framework and look up the manager class by name
        let path = "/System/Library/PrivateFrameworks/SidecarCore.framework/SidecarCore"
        guard dlopen(path, RTLD_LAZY) != nil,
              let managerClass = NSClassFromString("SidecarDisplayManager") as? NSObject.Type,
              class_respondsToSelector(object_getClass(managerClass), Selector(("sharedManager")))
        else { return nil }

        // Ask the class for its shared instance
        return managerClass.perform(Selector(("sharedManager")))?.takeUnretainedValue() as? NSObject
    }()

    /// Returns the Sidecar-capable devices SidecarCore can currently reach, as
    /// opaque framework objects. Returns an empty array if none are reachable.
    private static func devices() -> [NSObject] {
        guard let manager, manager.responds(to: Selector(("devices"))) else { return [] }
        return manager.perform(Selector(("devices")))?.takeUnretainedValue() as? [NSObject] ?? []
    }

    /// Returns the user-visible name of a device object, such as "Ryan's iPad".
    private static func name(of device: NSObject) -> String {
        device.perform(Selector(("name")))?.takeUnretainedValue() as? String ?? "iPad"
    }

    /// Connects to an iPad over Sidecar. If `preferredName` is set, connects to
    /// the device with that name (case-insensitive). Otherwise connects to the
    /// first reachable device. Calls `completion` on the main thread with the
    /// connected device's name, or with an error.
    static func connect(preferredName: String?, completion: @escaping (Result<String, Error>) -> Void) {
        // Fail early if the framework didn't load on this macOS version
        guard let manager else {
            completion(.failure(SidecarError.frameworkUnavailable))
            return
        }

        // Choose the target device
        let reachable = devices()
        guard !reachable.isEmpty else {
            completion(.failure(SidecarError.noDevices))
            return
        }
        let target: NSObject
        if let preferredName {
            guard let match = reachable.first(where: { name(of: $0).caseInsensitiveCompare(preferredName) == .orderedSame }) else {
                completion(.failure(SidecarError.deviceNotFound(preferredName)))
                return
            }
            target = match
        } else {
            target = reachable[0]
        }
        let targetName = name(of: target)

        // Ask SidecarCore to connect; its callback can arrive on any thread, so hop back to main
        let callback: @convention(block) (NSError?) -> Void = { error in
            DispatchQueue.main.async {
                if let error {
                    completion(.failure(error))
                } else {
                    completion(.success(targetName))
                }
            }
        }
        _ = manager.perform(Selector(("connectToDevice:completion:")), with: target, with: callback)
    }
}

/// Runs connection attempts (with a couple of retries) and remembers the
/// latest outcome so the menu can show it. All methods are called on the main thread.
final class SidecarController {
    /// The outcome of the most recent connection attempt.
    private enum State {
        case idle
        case connecting
        case connected(name: String, at: Date)
        case failed(message: String, at: Date)
    }

    private var state: State = .idle

    /// How many extra attempts to make after a failure, and how long to wait
    /// between them. Right after an unlock, the iPad often isn't discoverable yet.
    private let retries = 2
    private let retryDelay: TimeInterval = 5

    /// True while a connection attempt (including its retries) is running.
    var isConnecting: Bool {
        if case .connecting = state { return true }
        return false
    }

    /// Starts a connection attempt after `delay` seconds. Ignores the request
    /// if an attempt is already running.
    func reconnect(after delay: TimeInterval = 0) {
        // Skip if an attempt is already in progress
        guard !isConnecting else { return }
        state = .connecting

        // Start the first attempt after the delay
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.attempt(retriesLeft: self.retries)
        }
    }

    /// Makes one connection attempt and schedules a retry if it fails and
    /// retries remain. Records the final outcome in `state`.
    private func attempt(retriesLeft: Int) {
        // Use the iPad name from preferences if set; otherwise take the first reachable iPad
        let preferred = UserDefaults.standard.string(forKey: "DeviceName")

        SidecarCore.connect(preferredName: preferred) { result in
            switch result {
            case .success(let name):
                self.state = .connected(name: name, at: Date())
            case .failure(let error) where retriesLeft > 0:
                NSLog("Stagehand: Sidecar attempt failed, retrying: \(error.localizedDescription)")
                DispatchQueue.main.asyncAfter(deadline: .now() + self.retryDelay) {
                    self.attempt(retriesLeft: retriesLeft - 1)
                }
            case .failure(let error):
                NSLog("Stagehand: Sidecar connection failed: \(error.localizedDescription)")
                self.state = .failed(message: error.localizedDescription, at: Date())
            }
        }
    }

    /// Returns the gray header lines for the menu (text plus an optional tooltip),
    /// modeled on Time Machine's "Latest Backup to …" / "Yesterday, 8:41 AM".
    func statusLines() -> [(text: String, toolTip: String?)] {
        switch state {
        case .idle:
            return [("No Sidecar Connections Yet", nil)]
        case .connecting:
            return [("Connecting to Sidecar…", nil)]
        case .connected(let name, let date):
            return [("Latest Connection to “\(name)”", nil), (date.menuTimestamp, nil)]
        case .failed(let message, let date):
            return [("Couldn’t Connect to Sidecar", message), (date.menuTimestamp, message)]
        }
    }
}
