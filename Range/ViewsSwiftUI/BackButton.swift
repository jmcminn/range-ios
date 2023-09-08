import SwiftUI

struct BackButton: View {
    var callback: () -> Void

    var body: some View {
        Button(action: callback) {
            Image(systemName: "chevron.backward")
                .font(.system(size: 23, weight: .medium))
                .foregroundColor(.dynamic(.Neutral_04))
                .frame(width: 40, height: 40, alignment: .center)
        }
    }
}

struct BackButton_Previews: PreviewProvider {
    static var previews: some View {
        BackButton(callback: {})
    }
}
