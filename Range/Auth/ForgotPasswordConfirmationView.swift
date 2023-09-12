import SwiftUI

struct ForgotPasswordConfirmationView: View {
    let backAction: () -> Void
    let backToSignInAction: () -> Void
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

                    Spacer()

                    Image("emailImage")

                    Text("Password reset email sent")
                        .foregroundColor(.dynamic(.Neutral_04))
                        .font(.title3.bold())
                        .padding(EdgeInsets(top: 45, leading: 20, bottom: 10, trailing: 20))

                    Text("Go to your email to open the link")
                        .foregroundColor(.dynamic(.Neutral_05))
                        .font(.subheadline)
                        .padding(EdgeInsets(top: 5, leading: 20, bottom: 20, trailing: 20))

                    Spacer()

                    BlueGradientButton(text: "Back to sign in", clicked: backToSignInAction)
                }
                .multilineTextAlignment(.center)
                .padding(20)
            }
        }
    }
}

struct ForgotPasswordConfirmationView_Previews: PreviewProvider {
    static var previews: some View {
        ForgotPasswordConfirmationView(backAction: {}, backToSignInAction: {})
    }
}
