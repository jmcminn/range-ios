import Combine
import SwiftUI

/// View model for `EmailAuthView`
class EmailAuthViewModel: ObservableObject {
    /// email entered by user
    @Published var email = ""
    /// password entered by user
    @Published var password = ""
    /// whether the authentication is currently in progress
    @Published var isAuthenticating = false
}

/// A view for presenting email and password fields for authentication
struct EmailAuthView: View {
    @ObservedObject var viewModel: EmailAuthViewModel
    let authenticateAction: () -> Void
    let forgotPasswordAction: () -> Void
    let backAction: () -> Void
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

                // back button hidden when EmailAuthView is the first screen in the AuthFlow
//                HStack {
//                    BackButton(callback: backAction)
//                    Spacer()
//                }

                VStack(spacing: 0) {
                    Image("logo_side_by_side")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 40)
                        .padding(EdgeInsets(top: 12, leading: 0, bottom: 40, trailing: 0))

                    Text("Let's get started")
                        .foregroundColor(.dynamic(.Neutral_04))
                        .font(.title3.bold())
                        .padding(.bottom, 10)

                    Text("Enter your details to log in")
                        .foregroundColor(.dynamic(.Neutral_05))
                        .font(.subheadline)
                        .padding(EdgeInsets(top: 5, leading: 0, bottom: 20, trailing: 0))

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

                            SecureField("Your password", text: $viewModel.password,
                                        prompt: Text("Your password")
                                            .foregroundColor(.dynamic(.Neutral_05)))
                                .foregroundColor(.dynamic(.Neutral_04))
                                .onSubmit {
                                    focusedField = nil
                                    authenticateAction()
                                }
                                .textContentType(.password)
                                .focused($focusedField, equals: "password")
                                .padding(EdgeInsets(top: 0, leading: 0, bottom: 24, trailing: 0))
                        }
                        .font(.title3)
                        .accentColor(Color.Secondary_02)

                        Button("Log In") {
                            focusedField = nil
                            authenticateAction()
                        }
                        .buttonStyle(BlueGradientButtonStyle())

                        TranslucentButton(text: "Forgot password?", clicked: {
                            focusedField = nil
                            forgotPasswordAction()
                        })
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

struct EmailAuthView_Previews: PreviewProvider {
    static var previews: some View {
        EmailAuthView(viewModel: EmailAuthViewModel(), authenticateAction: {}, forgotPasswordAction: {}, backAction: {})
    }
}
