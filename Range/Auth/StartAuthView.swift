import Combine
import SwiftUI

class StartAuthViewModel: ObservableObject {
    /// whether the resending verification email is currently in progress
    @Published var isProcessing = false
}

struct StartAuthView: View {
    @ObservedObject var viewModel: StartAuthViewModel
    @Environment(\.colorScheme) var colorScheme
    let googleLoginAction: () -> Void
    let loginAction: () -> Void
    let signUpAction: () -> Void

    func earlyAccessInvitationAttributedString() -> AttributedString {
        var text =
            AttributedString(
                "👋 To sign up for Range you'll need an early access invitation, or be invited by your team members."
            )
        text.foregroundColor = .dynamic(.Neutral_07)

        if let earlyAccessRange = text.range(of: "early access invitation") {
            text[earlyAccessRange].link =
                URL(
                    string: "https://docs.google.com/forms/d/e/1FAIpQLSeu1TJGH75nM5Or1KGtYZ1q1AGR6yJLuAJ3cWsMzr1IRWk3jg/viewform"
                )
            text[earlyAccessRange].underlineStyle = .single
            text[earlyAccessRange].foregroundColor = .Primary_Blue_04
        }

        return text
    }

    func descriptionAttributedString() -> AttributedString {
        var text =
            AttributedString(
                "By signing up, or continuing with Google, you agree to our Terms of Service and Privacy Policy"
            )
        text.foregroundColor = .dynamic(.Neutral_04)

        if let privacyRange = text.range(of: "Privacy Policy") {
            text[privacyRange].link =
                URL(string: "https://rangehq.notion.site/Range-Privacy-Policy-7171e619c2ae42489a19fff06fbe47c6")
            text[privacyRange].underlineStyle = .single
            text[privacyRange].foregroundColor = .Primary_Blue_04
        }
        if let termsRange = text.range(of: "Terms of Service") {
            text[termsRange].link =
                URL(string: "https://rangehq.notion.site/Range-Terms-of-Service-27c0ae45b3b145a883b9cbc72231b32f")
            text[termsRange].underlineStyle = .single
            text[termsRange].foregroundColor = .Primary_Blue_04
        }
        return text
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // background that stays in place and ignores safe areas
                Group {
                    Color(.dynamic(.Neutral_10))
                    if colorScheme == .dark {
                        Image("topglow")
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width)
                    }
                }.edgesIgnoringSafeArea(.all)

                VStack(spacing: 0) {
                    HStack(alignment: .center, spacing: 10) {
                        Text(earlyAccessInvitationAttributedString())
                            .font(.subheadline.bold())
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(Color.dynamic(.Neutral_04))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)

                    Image("logo_side_by_side")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 40)
                        .padding(EdgeInsets(top: 72, leading: 0, bottom: 40, trailing: 0))

                    Text("Let's get started")
                        .foregroundColor(.dynamic(.Neutral_04))
                        .font(.title3.bold())
                        .padding(.bottom, 48)

                    VStack(alignment: .center, spacing: 24) {
                        Button(action: googleLoginAction) {
                            HStack {
                                Image("Google")
                                Text("Continue with Google")
                            }
                        }
                        .buttonStyle(GrayButtonStyle())

                        HStack(alignment: .center, spacing: 12) {
                            Rectangle().frame(height: 1).foregroundColor(.dynamic(.Neutral_07))
                            Text("Or").foregroundColor(.dynamic(.Neutral_05))
                            Rectangle().frame(height: 1).foregroundColor(.dynamic(.Neutral_07))
                        }
                        .padding(0)
                        .frame(maxWidth: .infinity, alignment: .center)

                        Button("Log in", action: loginAction)
                            .buttonStyle(GrayButtonStyle())

                        Button("Sign up", action: signUpAction)
                            .buttonStyle(BlueGradientButtonStyle())

                        Text(descriptionAttributedString())
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: /*@START_MENU_TOKEN@*/true/*@END_MENU_TOKEN@*/)
                    }
                    .disabled(viewModel.isProcessing)

                    Spacer()
                }
                .multilineTextAlignment(.center)
                .padding(20)
            }
            .overlay {
                if viewModel.isProcessing {
                    ProgressView()
                }
            }
        }
    }
}

struct StartAuthView_Previews: PreviewProvider {
    static var previews: some View {
        StartAuthView(
            viewModel: StartAuthViewModel(),
            googleLoginAction: {},
            loginAction: {},
            signUpAction: {}
        )
    }
}
