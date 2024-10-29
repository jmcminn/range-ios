import SwiftUI

struct OrganizationDisabledView: View {
    
    var organizationName: String
    
    func messageAttributedString() -> AttributedString {
        let supportEmail = "info@range.io"
        var text =
            AttributedString(
                "We are unable to support free users indefinitely. Please contact us at \(supportEmail) so that we can migrate your Organization to a paid plan in order to continue using Range."
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
                    Image("secure-lock 1")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 132)
                        .padding(EdgeInsets(top: 0, leading: 20, bottom: 20, trailing: 20))

                    Text("Your \(organizationName) Organization has been disabled for exceeding the limits of our free plan")
                        .foregroundColor(.dynamic(.Neutral_03))
                        .font(.title2.bold())
                        .padding(EdgeInsets(top: 0, leading: 32, bottom: 12, trailing: 32))

                    Text(messageAttributedString())
                        .padding(EdgeInsets(top: 0, leading: 32, bottom: 0, trailing: 32))
                }
            }
            .multilineTextAlignment(.center)
            .background(Color(.dynamic(.Neutral_10)))
        }
    }
}

#Preview {
    OrganizationDisabledView(organizationName: "Test")
}
