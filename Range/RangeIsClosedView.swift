import SwiftUI

struct RangeIsClosedView: View {
    func maintenanceAttributedString() -> AttributedString {
        let supportEmail = "support@range.io"
        var text =
            AttributedString(
                "We’re currently undergoing some scheduled maintenance. We apologize for the inconvenience, but we’ll be back online soon.\n\nIf you need to contact us, please email \(supportEmail)"
            )
        text.foregroundColor = .dynamic(.Neutral_05)
        text.font = .subheadline

        if let supportRange = text.range(of: supportEmail) {
            text[supportRange].link = URL(string: "mailto:\(supportEmail)")
            text[supportRange].foregroundColor = .Primary_Blue_04
            text[supportRange].font = .subheadline.bold()
        }

        return text
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Group {
                    Image("topglow")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width)
                    Image("bottomglow")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width)
                }.edgesIgnoringSafeArea(.all)

                VStack(spacing: 0) {
                    Image("logo_side_by_side")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 40)
                        .padding(EdgeInsets(top: 0, leading: 20, bottom: 40, trailing: 20))

                    Text("We’ll be back shortly...")
                        .foregroundColor(.dynamic(.Neutral_03))
                        .font(.title2.bold())
                        .padding(EdgeInsets(top: 0, leading: 32, bottom: 12, trailing: 32))

                    Text(maintenanceAttributedString())
                        .padding(EdgeInsets(top: 0, leading: 32, bottom: 0, trailing: 32))
                }
            }
            .multilineTextAlignment(.center)
            .background(Color(.dynamic(.Neutral_10)))
        }
    }
}

#Preview {
    RangeIsClosedView()
}
