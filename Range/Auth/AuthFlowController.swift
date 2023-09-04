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
        let authView = StartAuthView(
            loginAction: { [weak self] in self?.showEmailAndPasswordAuthView() },
            signUpAction: { [weak self] in self?.showEmailAndPasswordSignUpView() }
        )
        let vc = UIHostingController<StartAuthView>(rootView: authView)

        setViewControllers([vc], animated: false)
    }

    /// Initiates the authentication by email and password
    private func showEmailAndPasswordAuthView() {
        let emailAuthViewModel = EmailAuthViewModel()

        let emailAuthView = EmailAuthView(viewModel: emailAuthViewModel) { [weak self] in
            self?.authenticate(byEmailAndPassword: emailAuthViewModel)
        }

        let emailAuthViewController = UIHostingController<EmailAuthView>(rootView: emailAuthView)

        pushViewController(emailAuthViewController, animated: true)
    }

    /// Try to authenticate with given user input using `FirebaseAuth`.
    /// It resolves the flow when authentication succeeded and shows the error alert otherwise
    private func authenticate(byEmailAndPassword model: EmailAuthViewModel) {
        model.isAuthenticating = true
        Task { @MainActor in
            do {
                defer {
                    model.isAuthenticating = false
                }
                let authResult = try await Auth.auth().signIn(withEmail: model.email, password: model.password)
                let userId = try await authResult.user._getUserId()
                onAuthenticated(userId)
            } catch {
                self.showAuthenticationError(withMessage: self.message(forError: error))
            }
        }
    }

    private func showEmailAndPasswordSignUpView() {
        let viewModel = EmailSignUpViewModel()

        let emailSignUpVC = UIHostingController<EmailSignUpView>(
            rootView: EmailSignUpView(viewModel: viewModel) { [weak self] in
                self?.signUp(byEmailAndPassword: viewModel)
            }
        )
        pushViewController(emailSignUpVC, animated: true)
    }

    /// Try to sign up with given user input using `FirebaseAuth`.
    /// It resolves the flow when authentication succeeded and shows the error alert otherwise
    private func signUp(byEmailAndPassword model: EmailSignUpViewModel) {
        model.isAuthenticating = true
        Task { @MainActor in
            do {
                defer {
                    model.isAuthenticating = false
                }
                let authResult = try await Auth.auth().createUser(withEmail: model.email, password: model.password)
                let user = authResult.user
                try await user.sendEmailVerification()
                let userId = try await user._getUserId()
                onAuthenticated(userId)
            } catch {
                self.showAuthenticationError(withMessage: self.message(forError: error))
            }
        }
    }

    private func message(forError error: Error) -> String {
        // Extract information about the error from blocking function info in underlying errors
        if let e = (error as NSError).underlyingErrors.first,
           let responseInfo = (e as NSError).userInfo["FIRAuthErrorUserInfoDeserializedResponseKey"] as? [String: Any],
           let message = responseInfo["message"] as? String
        {
            // sometimes a message is just a code for error (when coming directly from auth)
            if message == "INVALID_LOGIN_CREDENTIALS" {
                return String(localized: "Your email or password is invalid")
            }
            // when coming from a blocking auth function, the message is a text but it has a json with message key embedded in it
            if let jsonStart = message.firstIndex(of: "{"), let jsonEnd = message.lastIndex(of: "}") {
                let jsonMessage = message[jsonStart ... jsonEnd]
                if let jsonMessageData = jsonMessage.data(using: .utf8) {
                    do {
                        if let jsonObject = try JSONSerialization.jsonObject(with: jsonMessageData) as? [String: Any],
                           let errorDict = jsonObject["error"] as? [String: Any],
                           let message = errorDict["message"] as? String
                        {
                            return message
                        }
                    } catch {
                        // ignore error
                    }
                }
            }
        }

        return error.localizedDescription
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
