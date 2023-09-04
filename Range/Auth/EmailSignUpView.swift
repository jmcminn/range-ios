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
    @FocusState private var focusedField: String?
    @Environment(\.colorScheme) var colorScheme

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
                                .onSubmit {
                                    focusedField = "password"
                                }
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .submitLabel(.next)

                            SecureField("Choose a password", text: $viewModel.password,
                                        prompt: Text("Choose a password")
                                            .foregroundColor(.dynamic(.Neutral_05)))
                                .onSubmit {
                                    focusedField = nil
                                    continueAction()
                                }
                                .textContentType(.password)
                                .focused($focusedField, equals: "password")
                        }
                        .font(.title3)
                        .accentColor(Color.Secondary_02)

                        BlueGradientButton(text: "Continue", clicked: {
                            focusedField = nil
                            continueAction()
                        })
                    }
                    .padding(EdgeInsets(top: 12, leading: 0, bottom: 22, trailing: 0))
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
        EmailSignUpView(viewModel: EmailSignUpViewModel(), continueAction: {})
            .preferredColorScheme(.dark)
    }
}
