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
    @FocusState private var focusedField: String?

    var body: some View {
        // GeometryReader is added as a hack to avoid the whole view moving up when
        // the keyboard appears: https://developer.apple.com/forums/thread/658432s
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // background that stays in place and ignores safe areas
                Group {
                    Color(.dynamicColor(light: .Neutral_01, dark: .Neutral_10))
                    Image("topglow")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width)
                }.edgesIgnoringSafeArea(.all)

                VStack(spacing: 0) {
                    Image("logo_side_by_side")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 40)
                        .padding(EdgeInsets(top: 12, leading: 0, bottom: 40, trailing: 0))

                    Text("Let's get started")
                        .foregroundColor(.dynamicColor(light: .Neutral_07, dark: .Neutral_04))
                        .font(.title3.bold())
                    Text("Please enter your email and password to continue")
                        .foregroundColor(.dynamicColor(light: .Neutral_06, dark: .Neutral_05))
                        .font(.subheadline)
                        .padding(EdgeInsets(top: 5, leading: 0, bottom: 20, trailing: 0))

                    Group {
                        TextField("Your e-mail", text: $viewModel.email) {
                            focusedField = "password"
                        }
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .submitLabel(.next)

                        SecureField("Your password", text: $viewModel.password) {
                            focusedField = nil
                            authenticateAction()
                        }
                        .textContentType(.password)
                        .focused($focusedField, equals: "password")
                    }
                    .padding(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
                    .font(.title3)
                    .accentColor(Color.Secondary_02)
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
        EmailAuthView(viewModel: EmailAuthViewModel(), authenticateAction: {})
            .preferredColorScheme(.dark)
    }
}
