import SwiftUI

class EnterAccountInfoViewModel: ObservableObject {
    /// email of the user
    @Published var email = "...@..."
    /// first name
    @Published var firstName = ""
    /// last name
    @Published var lastName = ""
    /// The job title of the user
    @Published var jobTitle: String? = nil
    /// whether the account is being updated
    @Published var isProcessing = false
}

/// View shown when the logged-in user info is not ready (so user is right after signup)
struct EnterAccountInfoView: View {
    @ObservedObject var viewModel: EnterAccountInfoViewModel
    let selectJobTitleAction: () -> Void
    let createAccountAction: () -> Void
    let logOutAction: () -> Void
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
                    Text("Logged in as")
                        .foregroundColor(.dynamic(.Neutral_05))
                        .font(.body.bold())
                        .padding(EdgeInsets(top: 5, leading: 0, bottom: 10, trailing: 0))
                    Text(viewModel.email)
                        .foregroundColor(.dynamic(.Neutral_04))
                        .font(.title3.bold())
                        .padding(EdgeInsets(top: 5, leading: 0, bottom: 10, trailing: 0))
                    Text(
                        "You’re almost there. Finish creating your Range account by completing the following information."
                    )
                    .foregroundColor(.dynamic(.Neutral_05))
                    .font(.subheadline)
                    .padding(EdgeInsets(top: 15, leading: 0, bottom: 20, trailing: 0))

                    Group {
                        Group {
                            TextField("First name", text: $viewModel.firstName, prompt: Text("First name")
                                .foregroundColor(.dynamic(.Neutral_05)))
                                .onSubmit {
                                    focusedField = "lastName"
                                }
                                .autocapitalization(.words)
                                .disableAutocorrection(true)
                                .textContentType(.name)
                                .keyboardType(.namePhonePad)
                                .submitLabel(.next)
                                .padding(EdgeInsets(top: 20, leading: 4, bottom: 10, trailing: 0))

                            TextField("Last name", text: $viewModel.lastName, prompt: Text("Last name")
                                .foregroundColor(.dynamic(.Neutral_05)))
                                .onSubmit {
                                    focusedField = "role"
                                }
                                .autocapitalization(.words)
                                .disableAutocorrection(true)
                                .textContentType(.familyName)
                                .keyboardType(.namePhonePad)
                                .submitLabel(.next)
                                .padding(EdgeInsets(top: 15, leading: 4, bottom: 10, trailing: 0))
                                .focused($focusedField, equals: "lastName")

                            DropdownButton(
                                placeholderText: "Job Title",
                                text: $viewModel.jobTitle,
                                clicked: selectJobTitleAction
                            )
                            .padding(EdgeInsets(top: 2, leading: 4, bottom: 10, trailing: 0))
                        }
                        .font(.title3.bold())
                        .accentColor(Color.Secondary_02)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.leading)

                        BlueGradientButton(text: "Create Account", clicked: {
                            focusedField = nil
                            createAccountAction()
                        })

                        TranslucentButton(text: "Log out", clicked: logOutAction)
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

struct EnterAccountInfoView_Previews: PreviewProvider {
    static var previews: some View {
        EnterAccountInfoView(
            viewModel: EnterAccountInfoViewModel(),
            selectJobTitleAction: {},
            createAccountAction: {},
            logOutAction: {}
        )
    }
}
