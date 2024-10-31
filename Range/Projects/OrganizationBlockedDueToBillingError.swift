import SwiftUI

struct OrganizationBlockedDueToBillingError: View {
    
    var userOrganizationRole: Participant.OrganizationRole
    
    func message() -> String {
        if userOrganizationRole == .Admin {
            "Your Range account has a billing issue, and the grace period has expired. To restore access to your team’s data, please visit app.range.io in a Web browser to update the payment details for your organization."
        } else {
            "Your Range account has a billing issue, and the grace period has expired. To restore access to your team’s data, please have a Range Admin visit app.range.io in a Web browser to update the payment details for your organization."
        }
    }

    func contactUsAttributedString() -> AttributedString {
        let supportEmail = "support@range.io"
        var text = AttributedString("Questions?. Contact us at \(supportEmail)")
        text.foregroundColor = .dynamic(.Neutral_05)
        text.font = .footnote

        if let supportRange = text.range(of: supportEmail) {
            text[supportRange].link = URL(string: "mailto:\(supportEmail)")
            text[supportRange].foregroundColor = .Primary_Blue_04
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

                    Text("Update Billing Information")
                        .foregroundColor(.dynamic(.Neutral_03))
                        .font(.title2.bold())
                        .padding(EdgeInsets(top: 0, leading: 32, bottom: 12, trailing: 32))

                    Text(message())
                    .foregroundColor(.dynamic(.Neutral_05))
                    .font(.subheadline)
                    .padding(EdgeInsets(top: 0, leading: 32, bottom: 12, trailing: 32))

                    Text(contactUsAttributedString())
                        .padding(EdgeInsets(top: 0, leading: 32, bottom: 0, trailing: 32))
                }
            }
            .multilineTextAlignment(.center)
            .background(Color(.dynamic(.Neutral_10)))
        }
    }
}

#Preview {
    OrganizationBlockedDueToBillingError(userOrganizationRole: .Admin)
}
