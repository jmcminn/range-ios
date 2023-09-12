
import Combine
import SwiftUI

class AwaitEmailVerificationViewModel: ObservableObject {
    /// whether the resending verification email is currently in progress
    @Published var isProcessing = false
}

struct AwaitEmailVerificationView: View {
    @ObservedObject var viewModel: AwaitEmailVerificationViewModel
    let resendAction: () -> Void
    let backAction: () -> Void
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

                    Text(
                        "Almost there, please check your email inbox and click the link we just sent to verify it's you."
                    )
                    .foregroundColor(.dynamic(.Neutral_05))
                    .font(.subheadline)
                    .padding(EdgeInsets(top: 45, leading: 20, bottom: 20, trailing: 20))

                    Spacer()

                    Group {
                        TranslucentButton(text: "Didn't receive it? Resend email", clicked: {
                            resendAction()
                        })
                    }
                    .padding(EdgeInsets(top: 12, leading: 0, bottom: 22, trailing: 0))
                    .disabled(viewModel.isProcessing)
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

struct AwaitEmailVerificationView_Previews: PreviewProvider {
    static var previews: some View {
        AwaitEmailVerificationView(viewModel: AwaitEmailVerificationViewModel(), resendAction: {}, backAction: {})
    }
}
