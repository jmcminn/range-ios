import SwiftUI

/// A custom view for Translucent button.
/// Not implemented as one of the `ButtonStyles` as I couldn't get the button to react to the whole width taps (where it's transparent too)
/// when using ButtonStyle
struct TranslucentButton: View {
    var text: String
    var clicked: () -> Void /// use closure for callback

    var body: some View {
        Button(action: clicked) {
            HStack {
                Text(text).font(.body.bold())
            }
            .foregroundColor(.Primary_Blue_04)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .center)
            .background(Color.clear)
            .cornerRadius(12)
        }
    }
}

struct TranslucentButton_Previews: PreviewProvider {
    static var previews: some View {
        TranslucentButton(text: "Didn't receive it? Resend email", clicked: {})
    }
}
