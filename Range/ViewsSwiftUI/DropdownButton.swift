import SwiftUI

struct DropdownButton: View {
    // displayed when text is nil
    var placeholderText: String
    var font: Font = .title3.bold()
    @Binding var text: String?
    var clicked: () -> Void /// use closure for callback

    var body: some View {
        Button(action: clicked) {
            HStack {
                if let text = text {
                    Group {
                        Text(text).frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.down")
                    }
                    .font(font)
                    .foregroundColor(.dynamic(.Neutral_04))
                } else {
                    Group {
                        Text(placeholderText).frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.down")
                    }
                    .font(font)
                    .foregroundColor(.dynamic(.Neutral_05))
                }
            }
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .center)
            .background(Color.clear)
            .cornerRadius(12)
        }
    }
}

struct DropdownButton_Previews: PreviewProvider {
    static var previews: some View {
        DropdownButton(placeholderText: "Job Title", text: .constant(nil), clicked: {})
        DropdownButton(placeholderText: "Job Title", text: .constant("Property Facility Manager"), clicked: {})
    }
}
