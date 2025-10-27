import Foundation
import AppKit

struct CalendarInfo: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var colorHex: String
    var provider: CalendarProvider
    var accountEmail: String
    var isPrimary: Bool = false

    var color: NSColor {
        NSColor(hex: colorHex) ?? .systemBlue
    }
}

extension CalendarInfo {
    static let preview = CalendarInfo(
        id: "primary",
        name: "Work Calendar",
        colorHex: "#4285F4",
        provider: .google,
        accountEmail: "user@example.com",
        isPrimary: true
    )
}

extension NSColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }

    func toHex() -> String {
        guard let components = cgColor.components, components.count >= 3 else {
            return "#000000"
        }
        let r = Int(components[0] * 255.0)
        let g = Int(components[1] * 255.0)
        let b = Int(components[2] * 255.0)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
