// Shared date formatting for the menu's status lines.
import Foundation

extension Date {
    /// Formats the date the way Time Machine's menu does, such as
    /// "Today, 9:41 AM" or "Yesterday, 8:41 AM".
    var menuTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter.string(from: self)
    }
}
