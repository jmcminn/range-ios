import SwiftUI
import UIKit

/// The applications uses Neutral_01 ... Neutral_10 colors which are white to black, but defined separately
/// for light and dark mode (see the color resources for the exact values).
/// But in both, light and dark, Neutral_01 is still the brightest color, so this color scheme still needs to be inverted when using for light/dark mode.
/// The code uses the dark colors from Figma. So whenever something is set in Figma to be Neutral_10, it'll use Neutral_10 in dark mode
/// and Neutral_01 in light (09 vs 02, 08 vs 03, 07 vs 04, 06 vs 05, ...)

extension Color {
    static let Archived = Color("Archived")
    static let BlueDotBlue = Color("BlueDotBlue")
    static let Green_01 = Color("Green_01")
    static let Green_02 = Color("Green_02")
    static let Green_03 = Color("Green_03")
    static let Green_04 = Color("Green_04")
    static let Green_05 = Color("Green_05")
    static let Neutral_01 = Color("Neutral_01")
    static let Neutral_02 = Color("Neutral_02")
    static let Neutral_03 = Color("Neutral_03")
    static let Neutral_04 = Color("Neutral_04")
    static let Neutral_05 = Color("Neutral_05")
    static let Neutral_06 = Color("Neutral_06")
    static let Neutral_07 = Color("Neutral_07")
    static let Neutral_08 = Color("Neutral_08")
    static let Neutral_09 = Color("Neutral_09")
    static let Neutral_10 = Color("Neutral_10")
    static let Orange_03 = Color("Orange_03")
    static let Orange_04 = Color("Orange_04")
    static let Orange_Banner = Color("Orange_Banner")
    static let Pink_01 = Color("Pink_01")
    static let Pink_02 = Color("Pink_02")
    static let Pink_03 = Color("Pink_03")
    static let Pink_04 = Color("Pink_04")
    static let Primary_Blue_01 = Color("Primary_Blue_01")
    static let Primary_Blue_02 = Color("Primary_Blue_02")
    static let Primary_Blue_03 = Color("Primary_Blue_03")
    static let Primary_Blue_04 = Color("Primary_Blue_04")
    static let Primary_Blue_06 = Color("Primary_Blue_06")
    static let Red_01 = Color("Red_01")
    static let Red_03 = Color("Red_03")
    static let Red_04 = Color("Red_04")
    static let Secondary_02 = Color("Secondary_02")
    static let Secondary_03 = Color("Secondary_03")
    static let Special_01 = Color("Special_01")
    static let Special_02 = Color("Special_02")
    static let Special_03 = Color("Special_03")
}

extension UIColor {
    static let Archived = UIColor(named: "Archived")!
    static let BlueDotBlue = UIColor(named: "BlueDotBlue")!
    static let Green_01 = UIColor(named: "Green_01")!
    static let Green_02 = UIColor(named: "Green_02")!
    static let Green_03 = UIColor(named: "Green_03")!
    static let Green_04 = UIColor(named: "Green_04")!
    static let Green_05 = UIColor(named: "Green_05")!
    /// white
    static let Neutral_01 = UIColor(named: "Neutral_01")!
    static let Neutral_02 = UIColor(named: "Neutral_02")!
    static let Neutral_03 = UIColor(named: "Neutral_03")!
    static let Neutral_04 = UIColor(named: "Neutral_04")!
    static let Neutral_05 = UIColor(named: "Neutral_05")!
    static let Neutral_06 = UIColor(named: "Neutral_06")!
    static let Neutral_07 = UIColor(named: "Neutral_07")!
    static let Neutral_08 = UIColor(named: "Neutral_08")!
    static let Neutral_09 = UIColor(named: "Neutral_09")!
    /// black
    static let Neutral_10 = UIColor(named: "Neutral_10")!
    static let Orange_03 = UIColor(named: "Orange_03")!
    static let Orange_04 = UIColor(named: "Orange_04")!
    static let Orange_Banner = UIColor(named: "Orange_Banner")!
    static let Pink_01 = UIColor(named: "Pink_01")!
    static let Pink_02 = UIColor(named: "Pink_02")!
    static let Pink_03 = UIColor(named: "Pink_03")!
    static let Pink_04 = UIColor(named: "Pink_04")!
    static let Primary_Blue_01 = UIColor(named: "Primary_Blue_01")!
    static let Primary_Blue_02 = UIColor(named: "Primary_Blue_02")!
    static let Primary_Blue_03 = UIColor(named: "Primary_Blue_03")!
    static let Primary_Blue_04 = UIColor(named: "Primary_Blue_04")!
    static let Primary_Blue_06 = UIColor(named: "Primary_Blue_06")!
    static let Red_01 = UIColor(named: "Red_01")!
    static let Red_03 = UIColor(named: "Red_03")!
    static let Red_04 = UIColor(named: "Red_04")!
    static let Secondary_02 = UIColor(named: "Secondary_02")!
    static let Secondary_03 = UIColor(named: "Secondary_03")!
    static let Special_01 = UIColor(named: "Special_01")!
    static let Special_02 = UIColor(named: "Special_02")!
    static let Special_03 = UIColor(named: "Special_03")!
}

/// Dynamic colors
extension UIColor {
    /// Color that automatically adapts to light/dark and specifies both values
    static func dynamicColor(light: UIColor, dark: UIColor) -> UIColor {
        UIColor { $0.userInterfaceStyle == .dark ? dark : light }
    }

    /// Color that adapts to light/dark and specifies dark only. For light appearance it uses `invertedColor(color)`
    static func dynamic(_ dark: UIColor) -> UIColor {
        dynamicColor(light: dark._inverted, dark: dark)
    }

    /// To translate Neutral colors between light and dark appearances
    fileprivate var _inverted: UIColor {
        switch self {
        case .Neutral_10: return .Neutral_01
        case .Neutral_09: return .Neutral_02
        case .Neutral_08: return .Neutral_03
        case .Neutral_07: return .Neutral_04
        case .Neutral_06: return .Neutral_05
        case .Neutral_05: return .Neutral_06
        case .Neutral_04: return .Neutral_07
        case .Neutral_03: return .Neutral_08
        case .Neutral_02: return .Neutral_09
        case .Neutral_01: return .Neutral_10
        default: fatalError("Neutral colors range from 1 to 10")
        }
    }
}

/// Highlight colors
extension UIColor {
    var _highlightColor: UIColor {
        // if the color is a clear color then return a clear color for highlight too
        var a: CGFloat = 0
        getRed(nil, green: nil, blue: nil, alpha: &a)
        if a <= 0 {
            return .clear
        }
        // Can't compare the UIColor directly, need to compare the components, so we can as well compare the hex representation
        switch hexString {
        case UIColor.Green_01.hexString: return .Green_02
        case UIColor.Green_03.hexString: return .Green_04
        case UIColor.Green_04.hexString: return .Green_05
        case UIColor.Orange_03.hexString: return .Orange_04
        case UIColor.Primary_Blue_03.hexString: return .Primary_Blue_04
        case UIColor.Primary_Blue_04.hexString: return .Primary_Blue_06
        case UIColor.Neutral_10.hexString: return .Neutral_09
        case UIColor.Neutral_09.hexString: return .Neutral_08
        case UIColor.Neutral_02.hexString: return .Neutral_03
        case UIColor.Neutral_01.hexString: return .Neutral_02
        case UIColor.Pink_01.hexString: return .Pink_02
        case UIColor.Secondary_02.hexString: return .Secondary_03
        case UIColor.Red_03.hexString: return .Red_04
        default:
            fatalError("highlight color not defined for \(hexString)")
        }
    }
}

extension Color {
    /// Color that automatically adapts to light/dark
    static func dynamicColor(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor.dynamicColor(light: light, dark: dark))
    }

    /// Color that adapts to light/dark and specifies dark only. For light appearance it uses `invertedColor(color)`
    static func dynamic(_ dark: UIColor) -> Color {
        dynamicColor(light: dark._inverted, dark: dark)
    }
}

extension UITraitEnvironment {
    /// shortcut for `traitCollection.userInterfaceStyle == .dark ? dark : light`
    ///
    /// For cases where UIColor.dynamicColor doesn't work - observed that it doesn't work when manually overriding userInterfaceStyle
    ///
    /// - Warning: Doesn't automatically change color!!!
    /// private for now, can be made public if we need it for other colors than Neutral (which is covered by chooseColor(_ dark:))
    private func chooseColor(light: UIColor, dark: UIColor) -> UIColor {
        traitCollection.userInterfaceStyle == .dark ? dark : light
    }

    /// - Warning: Doesn't automatically change color!!!
    func chooseColor(_ dark: UIColor) -> UIColor {
        traitCollection.userInterfaceStyle == .dark ? dark : dark._inverted
    }
}
