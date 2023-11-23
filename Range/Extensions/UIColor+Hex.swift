import Foundation
import UIKit

/// Extension for UIColor providing Hex value conversions
extension UIColor {
    /// Initiate the color with Hex value
    /// Accepts string of "#RRGGBB",  "RRGGBB", "#RRGGBBAA", "RRGGBBAA"
    convenience init?(hexString: String, alpha _: CGFloat = 1.0) {
        var hexString: String = hexString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if hexString.hasPrefix("#") {
            hexString.removeFirst()
        }
        let scanner = Scanner(string: hexString)

        var rgbValue: UInt64 = 0
        guard scanner.scanHexInt64(&rgbValue) else {
            return nil
        }

        var r, g, b, a: UInt64
        switch hexString.count {
        case 6:
            r = (rgbValue >> 16)
            g = (rgbValue >> 8 & 0xFF)
            b = (rgbValue & 0xFF)
            a = 255
        case 8:
            r = (rgbValue >> 16)
            g = (rgbValue >> 8 & 0xFF)
            b = (rgbValue & 0xFF)
            a = rgbValue >> 24
        default:
            return nil
        }

        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }

    var hexString: String { toHexString() }

    /// Produces hex string "#RRGGBB" if alpha == 1, else "#RRGGBBAA"
    func toHexString() -> String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        let rgb = Int(r * 255) << 16 | Int(g * 255) << 8 | Int(b * 255) << 0
        var hex = String(format: "#%06x", rgb)
        if a < 1 {
            hex += String(format: "%02x", Int(a * 255))
        }
        return hex
    }
}
