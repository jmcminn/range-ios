import FirebaseAuth
import SnapKit
import SwiftUI
import UIKit

/// The flow controller for authentication
final class AuthFlowController: UIViewController {
    /// callback for when authentication has successfully finished
    let onAuthenticated: () -> Void

    /// Initiates with callback for resolving the flow.
    /// - Important: Please note that this flow can only be resolved after the user successfully authenticates
    /// - Parameters:
    ///   - onAuthenticated: callback for resolving the flow
    init(onAuthenticated: @escaping () -> Void) {
        self.onAuthenticated = onAuthenticated
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func start() {
        showEmailAndPasswordAuthView()
    }

    /// Initiates the authentication by email and password
    private func showEmailAndPasswordAuthView() {
        let emailAuthViewModel = EmailAuthViewModel()

        let emailAuthViewController = UIHostingController<EmailAuthView>(
            rootView: EmailAuthView(
                viewModel: emailAuthViewModel
            ) { [weak self] in
                self?.authenticate(byEmailAndPassword: emailAuthViewModel)
            }
        )

        add(childController: emailAuthViewController)
        emailAuthViewController.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    /// Try to authenticate with given user input using `FirebaseAuth`.
    /// It resolves the flow when authentication succeeded and shows the error alert otherwise
    private func authenticate(byEmailAndPassword model: EmailAuthViewModel) {
        model.isAuthenticating = true
        Auth.auth()
            .signIn(withEmail: model.email, password: model.password) { [weak self] _, error in
                model.isAuthenticating = false
                guard error == nil else {
                    self?.showAuthenticationError(withMessage: error!.localizedDescription)
                    return
                }
                self?.onAuthenticated()
            }
    }

    /// Present alert controller with authentication error message
    private func showAuthenticationError(withMessage message: String) {
        let alertController = UIAlertController(
            title: "Authentication failed",
            message: message,
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "Ok", style: .cancel) { _ in
            alertController.dismiss(animated: true)
        })
        present(alertController, animated: true)
    }
}
