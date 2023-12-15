
import Foundation
import SwiftUI

struct BlueButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .center)
            .foregroundStyle(.white)
            .background(configuration.isPressed ? Color.Primary_Blue_06 : Color.Primary_Blue_04)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.Primary_Blue_06, lineWidth: 1)
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
