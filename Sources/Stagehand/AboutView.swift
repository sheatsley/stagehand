// The About window's contents, laid out like macOS's "About This Mac" panel.
import AppKit
import SwiftUI

/// App metadata read from Info.plist. build.sh writes these values at build
/// time (version, commit hash, website, copyright line).
struct AppInfo {
    let name: String
    let version: String
    let commit: String
    let developer: String
    let website: URL
    let copyright: String

    /// Reads the running bundle's Info.plist, falling back to placeholders when
    /// running outside a bundle (for example, `swift run` during development).
    static let current: AppInfo = {
        let info = Bundle.main.infoDictionary ?? [:]
        return AppInfo(
            name: info["CFBundleName"] as? String ?? "Stagehand",
            version: info["CFBundleShortVersionString"] as? String ?? "dev",
            commit: info["GitCommit"] as? String ?? "unknown",
            developer: info["Developer"] as? String ?? "Ryan Sheatsley",
            website: URL(string: info["ProjectWebsite"] as? String ?? "") ?? URL(string: "https://github.com")!,
            copyright: info["NSHumanReadableCopyright"] as? String ?? ""
        )
    }()
}

/// The About panel. Shows the app icon, name, and version, then a two-column
/// grid (white labels on the right edge of the left column, gray values on
/// the left edge of the right column), then the copyright/license line at the bottom.
struct AboutView: View {
    private let info = AppInfo.current

    var body: some View {
        VStack(spacing: 0) {
            // Icon, name, and version, centered like About This Mac
            Image(nsImage: icon)
                .resizable()
                .frame(width: 128, height: 128)
            Text(info.name)
                .font(.system(size: 26, weight: .bold))
                .padding(.top, 10)
            Text("Version \(info.version)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.top, 2)

            // Label/value rows: white labels, gray values
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 4) {
                row("Developer") { Text(info.developer) }
                row("Build") { Text(info.commit).textSelection(.enabled) }
                row("Website") {
                    Link(info.website.host().map { $0 + info.website.path() } ?? info.website.absoluteString,
                         destination: info.website)
                }
            }
            .font(.system(size: 11))
            .padding(.top, 22)

            // Copyright and license line pinned to the bottom
            Spacer(minLength: 28)
            Text(info.copyright)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
        .padding(.top, 34)
        .padding(.bottom, 18)
        .frame(width: 290, height: 400)
    }

    /// The bundle's icon if build.sh added one (from Resources/AppIcon.png),
    /// otherwise the drawn placeholder.
    private var icon: NSImage {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleIconFile") != nil
            ? NSApp.applicationIconImage
            : AppIconArt.make()
    }

    /// Builds one grid row: a right-aligned white label and a left-aligned gray value.
    private func row<Value: View>(_ label: String, @ViewBuilder value: () -> Value) -> some View {
        GridRow {
            Text(label)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .gridColumnAlignment(.trailing)
            value()
                .foregroundStyle(.secondary)
        }
    }
}
