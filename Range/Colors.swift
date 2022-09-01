import SwiftUI
import UIKit

extension Color {
    static let Green_03 = Color("Green_03")
    static let Green_04 = Color("Green_04")
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
    static let Pink_03 = Color("Pink_03")
    static let Pink_04 = Color("Pink_04")
    static let Primary_Blue_02 = Color("Primary_Blue_02")
    static let Primary_Blue_04 = Color("Primary_Blue_04")
    static let Primary_Blue_06 = Color("Primary_Blue_06")
    static let Red_03 = Color("Red_03")
    static let Red_04 = Color("Red_04")
    static let Secondary_02 = Color("Secondary_02")
    static let Secondary_03 = Color("Secondary_03")
}

extension UIColor {
    static let Green_03 = UIColor(named: "Green_03")!
    static let Green_04 = UIColor(named: "Green_04")!
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
    static let Pink_03 = UIColor(named: "Pink_03")!
    static let Pink_04 = UIColor(named: "Pink_04")!
    static let Primary_Blue_02 = UIColor(named: "Primary_Blue_02")!
    static let Primary_Blue_04 = UIColor(named: "Primary_Blue_04")!
    static let Primary_Blue_06 = UIColor(named: "Primary_Blue_06")!
    static let Red_03 = UIColor(named: "Red_03")!
    static let Red_04 = UIColor(named: "Red_04")!
    static let Secondary_02 = UIColor(named: "Secondary_02")!
    static let Secondary_03 = UIColor(named: "Secondary_03")!
}

extension UIColor {
    /// Color that automatically adapts to light/dark
    static func dynamicColor(light: UIColor, dark: UIColor) -> UIColor {
        UIColor { $0.userInterfaceStyle == .dark ? dark : light }
    }
}

extension Color {
    /// Color that automatically adapts to light/dark
    static func dynamicColor(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor.dynamicColor(light: light, dark: dark))
    }
}

extension UITraitEnvironment {
    /// shortcut for `traitCollection.userInterfaceStyle == .dark ? dark : light`
    ///
    /// For cases where UIColor.dynamicColor doesn't work - observed that it doesn't work when manually overriding userInterfaceStyle
    ///
    /// - Warning: Doesn't automatically change color!!!
    func chooseColor(light: UIColor, dark: UIColor) -> UIColor {
        traitCollection.userInterfaceStyle == .dark ? dark : light
    }
}
