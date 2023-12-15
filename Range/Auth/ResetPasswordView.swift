import SwiftUI

class ResetPasswordViewModel: ObservableObject {
    /// email for which the password is changed
    @Published var email = "...@..."
    /// password entered by user
    @Published var password = ""
    /// password confirmation entered by user
    @Published var passwordConfirmation = ""
    /// whether the new password is being updated
    @Published var isProcessing = false
}

struct ResetPasswordView: View {
    @ObservedObject var viewModel: ResetPasswordViewModel
    let updatePasswordAction: () -> Void
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

                    Text("Please enter a new password for")
                        .foregroundColor(.dynamic(.Neutral_05))
                        .font(.subheadline)
                        .padding(EdgeInsets(top: 5, leading: 0, bottom: 0, trailing: 0))
                    Text(viewModel.email)
                        .foregroundColor(.dynamic(.Neutral_04))
                        .font(.title3.bold())
                        .padding(EdgeInsets(top: 5, leading: 0, bottom: 50, trailing: 0))

                    Group {
                        Group {
                            SecureField("Enter new password", text: $viewModel.password,
                                        prompt: Text("Enter new password")
                                            .foregroundColor(.dynamic(.Neutral_05)))
                                .foregroundColor(.dynamic(.Neutral_04))
                                .onSubmit {
                                    focusedField = "passwordConfirmation"
                                }
                                .textContentType(.newPassword)
                                .focused($focusedField, equals: "password")
                                .padding(EdgeInsets(top: 0, leading: 0, bottom: 24, trailing: 0))

                            SecureField("Re-enter your new password", text: $viewModel.passwordConfirmation,
                                        prompt: Text("Re-enter your new password")
                                            .foregroundColor(.dynamic(.Neutral_05)))
                                .foregroundColor(.dynamic(.Neutral_04))
                                .onSubmit {
                                    focusedField = nil
                                    updatePasswordAction()
                                }
                                .textContentType(.newPassword)
                                .focused($focusedField, equals: "passwordConfirmation")
                                .padding(EdgeInsets(top: 0, leading: 0, bottom: 24, trailing: 0))
                        }
                        .font(.title3)
                        .accentColor(Color.Secondary_02)

                        Button("Reset Password") {
                            focusedField = nil
                            updatePasswordAction()
                        }
                        .buttonStyle(BlueGradientButtonStyle())
                    }
                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 10, trailing: 0))
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

struct ResetPasswordView_Previews: PreviewProvider {
    static var previews: some View {
        ResetPasswordView(viewModel: ResetPasswordViewModel(), updatePasswordAction: {}, backAction: {})
    }
}
