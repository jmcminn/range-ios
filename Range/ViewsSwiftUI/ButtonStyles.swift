
import Foundation
import SwiftUI

/// Extensions for better syntax of applying a style to a button (so instead of `.buttonStyle(GrayButtonStyle())` one
/// can use `.buttonStyle(._gray)`
extension ButtonStyle where Self == BlueButtonStyle {
    static var _blue: BlueButtonStyle { BlueButtonStyle() }
}

extension ButtonStyle where Self == GrayButtonStyle {
    static var _gray: GrayButtonStyle { GrayButtonStyle() }
}

struct BlueButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .center)
            .foregroundStyle(isEnabled ? .white : .white.opacity(0.5))
            .background(
                isEnabled
                    ? (configuration.isPressed ? Color.Primary_Blue_06 : Color.Primary_Blue_04)
                    : Color.Primary_Blue_02
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isEnabled ? Color.Primary_Blue_06 : Color.Primary_Blue_02, lineWidth: 1)
            )
    }
}

struct BlueGradientButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .center)
            .foregroundStyle(.white)
            .background(
                LinearGradient(gradient: Gradient(colors: [
                    configuration.isPressed ? .Primary_Blue_06 : .Primary_Blue_04,
                    Color(red: 0.32, green: 0.28, blue: 0.81),
                ]),
                startPoint: .top, endPoint: .bottom)
            )
            .cornerRadius(12)
    }
}

struct GrayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .center)
            .foregroundStyle(Color.dynamic(.Neutral_04))
            .background(configuration.isPressed ? Color.dynamic(.Neutral_07) : Color.dynamic(.Neutral_09))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.dynamic(.Neutral_07), lineWidth: 1)
            )
    }
}
