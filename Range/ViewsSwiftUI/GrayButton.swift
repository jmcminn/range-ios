import SwiftUI

struct GrayButton: View {
    var text: String
    var imageName: String?
    var clicked: () -> Void /// use closure for callback

    var body: some View {
        Button(action: clicked) {
            HStack {
                if let imageName = imageName { Image(imageName) }
                Text(text)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .center)
            .foregroundColor(.dynamic(.Neutral_04))
            .background(Color.dynamic(.Neutral_09))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.dynamic(.Neutral_07), lineWidth: 1)
            )
        }
    }
}

struct GrayButton_Previews: PreviewProvider {
    static var previews: some View {
        GrayButton(text: "Log In", clicked: {})
    }
}
