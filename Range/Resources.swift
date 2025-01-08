import Foundation

/// given prefix name, number and suffix produces full name <prefix><number><suffix> for numbers 0..8 and <prefix>9+<suffix> for numbers >= 9
func numberedImageName(_ prefix: String, _ number: Int, _ suffix: String? = nil) -> String {
    prefix + (number < 9 ? String(number) : "9+") + (suffix ?? "")
}
