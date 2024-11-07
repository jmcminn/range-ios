import SwiftUI

struct OrganizationBlockedDueToBillingError: View {
    var isCardDeclinedBillingError: Bool
    var userOrganizationRole: Participant.OrganizationRole

    func title() -> String {
        if isCardDeclinedBillingError {
            "Update Billing Information"
        } else {
            "Critical Billing Issue Unresolved"
        }
    }

    func message() -> String {
        if isCardDeclinedBillingError {
            if userOrganizationRole == .Admin {
                "Your Range account has a billing issue, and the grace period has expired. To restore access to your team’s data, please visit app.range.io in a Web browser to update the payment details for your organization."
            } else {
                "Your Range account has a billing issue, and the grace period has expired. To restore access to your team’s data, please have a Range Admin visit app.range.io in a Web browser to update the payment details for your organization."
            }
        } else {
            "We’ve identified a billing issue that needs to be resolved immediately for this Organization to continue using Range."
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

                    Text(title())
                        .foregroundColor(.dynamic(.Neutral_03))
                        .font(.title2.bold())
                        .padding(EdgeInsets(top: 0, leading: 24, bottom: 12, trailing: 24))

                    Text(message())
                        .foregroundColor(.dynamic(.Neutral_05))
                        .font(.subheadline)
                        .padding(EdgeInsets(top: 0, leading: 24, bottom: 12, trailing: 24))

                    Text(contactUsAttributedString())
                        .padding(EdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24))

                    if !isCardDeclinedBillingError, userOrganizationRole == .Admin {
                        Button("Contact Us", action: {
                            guard let url = URL(string: "mailto:support@range.io") else { return }
                            UIApplication.shared.open(url)
                        })
                        .buttonStyle(BlueButtonStyle())
                        .padding(EdgeInsets(top: 24, leading: 24, bottom: 0, trailing: 24))
                    }
                }
            }
            .multilineTextAlignment(.center)
            .background(Color(.dynamic(.Neutral_10)))
        }
    }
}

#Preview {
    OrganizationBlockedDueToBillingError(isCardDeclinedBillingError: true, userOrganizationRole: .Admin)
}
