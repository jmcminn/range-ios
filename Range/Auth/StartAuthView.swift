import Combine
import SwiftUI

struct StartAuthView: View {
    @Environment(\.colorScheme) var colorScheme
    let loginAction: () -> Void

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
                    Image("logo_side_by_side")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 40)
                        .padding(EdgeInsets(top: 12, leading: 0, bottom: 40, trailing: 0))

                    Text("Let's get started")
                        .foregroundColor(.dynamic(.Neutral_05))
                        .font(.title3.bold())
                        .padding(.bottom, 48)

                    VStack(alignment: .center, spacing: 24) {
                        GrayButton(text: "Continue with Google", imageName: "Google", clicked: {})
                            .disabled(true)

                        HStack(alignment: .center, spacing: 12) {
                            Rectangle().frame(height: 1).foregroundColor(.dynamic(.Neutral_07))
                            Text("Or").foregroundColor(.dynamic(.Neutral_05))
                            Rectangle().frame(height: 1).foregroundColor(.dynamic(.Neutral_07))
                        }
                        .padding(0)
                        .frame(maxWidth: .infinity, alignment: .center)

                        GrayButton(text: "Log in", clicked: loginAction)

                        BlueGradientButton(text: "Sign up", clicked: {})
                            .disabled(true)
                    }

                    Spacer()
                }
                .multilineTextAlignment(.center)
                .padding(20)
            }
        }
    }
}

struct StartAuthView_Previews: PreviewProvider {
    static var previews: some View {
        StartAuthView(loginAction: {})
    }
}
