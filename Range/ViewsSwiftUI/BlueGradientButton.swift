import SwiftUI

struct BlueGradientButton: View {
    var text: String
    var clicked: () -> Void /// use closure for callback

    var body: some View {
        Button(action: clicked) {
            HStack {
                Text(text)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .center)
            .background(
                LinearGradient(gradient: Gradient(colors: [
                    .Primary_Blue_04,
                    Color(red: 0.32, green: 0.28, blue: 0.81),
                ]),
                startPoint: .top, endPoint: .bottom)
            )
            .cornerRadius(12)
        }
    }
}

struct BlueGradientButton_Previews: PreviewProvider {
    static var previews: some View {
        BlueGradientButton(text: "Log In", clicked: {})
    }
}
