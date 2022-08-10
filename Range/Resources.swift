import Foundation

/// given base name and number produces full name <base><number> for numbers 0..8 and <base>9+ for numbers >= 9
func numberedImageName(_ base: String, _ number: Int) -> String {
    base + (number < 9 ? String(number) : "9+")
}
