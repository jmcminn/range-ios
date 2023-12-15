import Combine
import SwiftUI

/// View model for `EmailSignUpView`
class EmailSignUpViewModel: ObservableObject {
    /// email entered by user
    @Published var email = ""
    /// password entered by user
    @Published var password = ""
    /// whether the authentication is currently in progress
    @Published var isAuthenticating = false
}

/// A view for presenting email and password fields for sign up
struct EmailSignUpView: View {
    @ObservedObject var viewModel: EmailSignUpViewModel
    let continueAction: () -> Void
    let backAction: () -> Void
    @FocusState private var focusedField: String?
    @Environment(\.colorScheme) var colorScheme

    func descriptionAttributedString() -> AttributedString {
        var text = AttributedString("By tapping continue, you agree to our Terms of Service and Privacy Policy")
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
        // GeometryReader is added as a hack to avoid the whole view moving up when
        // the keyboard appears: https://developer.apple.com/forums/thread/658432s
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

                HStack {
                    BackButton(callback: backAction)
                    Spacer()
                }

                VStack(spacing: 0) {
                    Image("logo_side_by_side")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 40)
                        .padding(EdgeInsets(top: 12, leading: 0, bottom: 40, trailing: 0))

                    Text("Get started by entering your email and choosing a password")
                        .foregroundColor(.dynamic(.Neutral_05))
                        .font(.subheadline)
                        .padding(EdgeInsets(top: 5, leading: 20, bottom: 20, trailing: 20))

                    Group {
                        Group {
                            TextField("Your email", text: $viewModel.email,
                                      prompt: Text("Your email")
                                          .foregroundColor(.dynamic(.Neutral_05)))
                                .foregroundColor(.dynamic(.Neutral_04))
                                .onSubmit {
                                    focusedField = "password"
                                }
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .submitLabel(.next)
                                .padding(EdgeInsets(top: 24, leading: 0, bottom: 36, trailing: 0))

                            SecureField("Choose a password", text: $viewModel.password,
                                        prompt: Text("Choose a password")
                                            .foregroundColor(.dynamic(.Neutral_05)))
                                .foregroundColor(.dynamic(.Neutral_04))
                                .onSubmit {
                                    focusedField = nil
                                    continueAction()
                                }
                                .textContentType(.newPassword)
                                .focused($focusedField, equals: "password")
                                .padding(EdgeInsets(top: 0, leading: 0, bottom: 24, trailing: 0))
                        }
                        .font(.title3)
                        .accentColor(Color.Secondary_02)

                        Button("Continue") {
                            focusedField = nil
                            continueAction()
                        }
                        .buttonStyle(BlueGradientButtonStyle())

                        Text(descriptionAttributedString())
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: /*@START_MENU_TOKEN@*/true/*@END_MENU_TOKEN@*/)
                            .padding(EdgeInsets(top: 24, leading: 0, bottom: 0, trailing: 0))
                    }
                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 10, trailing: 0))
                    .disabled(viewModel.isAuthenticating)

                    Spacer()
                }
                .multilineTextAlignment(.center)
                .padding(20)
            }
            .overlay {
                if viewModel.isAuthenticating {
                    ProgressView()
                }
            }
        }
    }
}

struct EmailSignUpView_Previews: PreviewProvider {
    static var previews: some View {
        EmailSignUpView(viewModel: EmailSignUpViewModel(), continueAction: {}, backAction: {})
    }
}
