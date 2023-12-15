import SwiftUI

class ForgotPasswordViewModel: ObservableObject {
    /// email entered by user
    @Published var email = ""
    /// whether sending the link to reset the pass is currently in progress
    @Published var isProcessing = false
}

struct ForgotPasswordView: View {
    @ObservedObject var viewModel: ForgotPasswordViewModel
    let sendLinkAction: () -> Void
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

                    Text("Enter your email below and we'll send you a link to reset your password.")
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
                                    focusedField = nil
                                    sendLinkAction()
                                }
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .submitLabel(.next)
                                .padding(EdgeInsets(top: 24, leading: 0, bottom: 36, trailing: 0))
                        }
                        .font(.title3)
                        .accentColor(Color.Secondary_02)

                        Button("Send me the link") {
                            focusedField = nil
                            sendLinkAction()
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

struct ForgotPasswordView_Previews: PreviewProvider {
    static var previews: some View {
        ForgotPasswordView(viewModel: ForgotPasswordViewModel(), sendLinkAction: {}, backAction: {})
    }
}
