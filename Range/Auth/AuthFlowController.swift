import FirebaseAuth
import SnapKit
import SwiftUI
import UIKit

/// The flow controller for authentication
final class AuthFlowController: UINavigationController, UINavigationControllerDelegate {
    /// callback for when authentication has successfully finished, called with the Range userId
    let onAuthenticated: (String) -> Void

    /// Initiates with callback for resolving the flow.
    /// - Important: Please note that this flow can only be resolved after the user successfully authenticates
    /// - Parameters:
    ///   - onAuthenticated: callback for resolving the flow, called with the Range userId
    init(onAuthenticated: @escaping (String) -> Void) {
        self.onAuthenticated = onAuthenticated
        super.init(nibName: nil, bundle: nil)
        delegate = self
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func start() {
        showStartAuthView()
    }

    /// set custom back button when showing a view controller - we don't want the "back" text
    func navigationController(_: UINavigationController, willShow viewController: UIViewController, animated _: Bool) {
        let item = UIBarButtonItem(title: " ", style: .plain, target: nil, action: nil)
        item.tintColor = .dynamic(.Neutral_04)
        viewController.navigationItem.backBarButtonItem = item
    }

    private func showStartAuthView() {
        let authView = StartAuthView { [weak self] in
            self?.showEmailAndPasswordAuthView()
        }
        let vc = UIHostingController<StartAuthView>(rootView: authView)

        setViewControllers([vc], animated: false)
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
        pushViewController(emailAuthViewController, animated: true)
    }

    /// Try to authenticate with given user input using `FirebaseAuth`.
    /// It resolves the flow when authentication succeeded and shows the error alert otherwise
    private func authenticate(byEmailAndPassword model: EmailAuthViewModel) {
        model.isAuthenticating = true
        Auth.auth()
            .signIn(withEmail: model.email, password: model.password) { [weak self] result, error in
                guard let self = self else { return }
                model.isAuthenticating = false
                guard error == nil else {
                    self.showAuthenticationError(withMessage: error!.localizedDescription)
                    return
                }
                guard let user = result?.user else {
                    self.showAuthenticationError(withMessage: "Unknown error")
                    return
                }
                getUserId(forUser: user) { result in
                    switch result {
                    case let .failure(error):
                        self.showAuthenticationError(withMessage: error.localizedDescription)
                    case let .success(userId):
                        self.onAuthenticated(userId)
                    }
                }
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
