import Firebase
import FirebaseAuth
import GoogleSignIn
import OSLog
import SnapKit
import SwiftUI
import UIKit

/// The flow controller for authentication
final class AuthFlowController: UINavigationController, UINavigationControllerDelegate {
    /// callback for when authentication has successfully finished, called with the Range userId
    let onAuthenticated: (String) -> Void

    /// Timer used to poll the user data with given time interval
    var checkEmailVerifiedTimer: Timer?

    /// Initiates with callback for resolving the flow.
    /// - Important: Please note that this flow can only be resolved after the user successfully authenticates
    /// - Parameters:
    ///   - onAuthenticated: callback for resolving the flow, called with the Range userId
    init(onAuthenticated: @escaping (String) -> Void) {
        self.onAuthenticated = onAuthenticated
        super.init(nibName: nil, bundle: nil)
        delegate = self
        // hide the navigation bar, we need custom back navigation
        isNavigationBarHidden = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// set custom back button when showing a view controller - we don't want the "back" text
    func navigationController(_: UINavigationController, willShow viewController: UIViewController, animated _: Bool) {
        // the "topGlow" background can be too wide on some devices and there's no nice way
        // to clip it in the swiftUI view that make it still cover the safe area...
        viewController.view.clipsToBounds = true
    }

    func start() {
        showStartAuthView()
    }

    private func showStartAuthView() {
        let startAuthViewModel = StartAuthViewModel()
        let authView = StartAuthView(
            viewModel: startAuthViewModel,
            googleLoginAction: { [weak self] in self?.signInWithGoogle(startAuthViewModel) },
            loginAction: { [weak self] in self?.showEmailAndPasswordAuthView() },
            signUpAction: { [weak self] in self?.showEmailAndPasswordSignUpView() }
        )
        let startVC = UIHostingController<StartAuthView>(rootView: authView)

        var vcs: [UIViewController] = [startVC]

        if let user = Auth.auth().currentUser, !user.isEmailVerified {
            // if user is signed in then show AwaitEmailVerificationView on top (going back does sign out)
            // if user is signed in and email is verified the auth flow should never be started...
            vcs.append(setupAwaitEmailVerificationView())
        }

        setViewControllers(vcs, animated: false)
    }
}

// MARK: - Google sign in

extension AuthFlowController {
    private func signInWithGoogle(_ viewModel: StartAuthViewModel) {
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }

        viewModel.isProcessing = true

        // Create Google Sign In configuration object.
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        Task { @MainActor in
            do {
                defer {
                    viewModel.isProcessing = false
                }
                let gidResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: self)
                let gidUser = gidResult.user
                guard let idTokenString = gidUser.idToken?.tokenString else {
                    throw "Cannot login using the provided account. Please contact the support."
                    return
                }
                let credential = GoogleAuthProvider.credential(
                    withIDToken: idTokenString,
                    accessToken: gidUser.accessToken.tokenString
                )
                let authResult = try await Auth.auth().signIn(with: credential)
                let user = authResult.user
                let userId = try await user._getUserId()
                // no need to check if email is verified. For Google sign in it should be always auto verified
                if !user.isEmailVerified {
                    // this shouldn't happen
                    throw "Email not verified for Google sign in. Please contact the support."
                }
                onAuthenticated(userId)
            } catch {
                let errorDomain = (error as NSError).domain
                let errorCode = (error as NSError).code
                if errorDomain == kGIDSignInErrorDomain, errorCode == GIDSignInError.canceled.rawValue {
                    // cancellation is not considered an error, don't show the error message
                    return
                }
                let message = error._messageForAuthError()
                Logger.auth.error("GoogleSignIn error \(message)")
                self.showAuthenticationError(withMessage: message)
            }
        }
    }
}

// MARK: - sign in

extension AuthFlowController {
    /// Initiates the authentication by email and password
    private func showEmailAndPasswordAuthView() {
        let emailAuthViewModel = EmailAuthViewModel()

        let emailAuthView = EmailAuthView(
            viewModel: emailAuthViewModel,
            authenticateAction: { [weak self] in self?.authenticate(byEmailAndPassword: emailAuthViewModel) },
            forgotPasswordAction: { [weak self] in self?.showForgotPasswordView() },
            backAction: { [weak self] in self?.popViewController(animated: true) }
        )

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
                let user = authResult.user
                let userId = try await user._getUserId()
                if !user.isEmailVerified {
                    self.showAwaitEmailVerificationView()
                } else {
                    onAuthenticated(userId)
                }
            } catch {
                let message = error._messageForAuthError()
                Logger.auth.error("signIn error \(message)")
                self.showAuthenticationError(withMessage: message)
            }
        }
    }
}

// MARK: - forgot password

extension AuthFlowController {
    private func showForgotPasswordView() {
        let viewModel = ForgotPasswordViewModel()

        let view = ForgotPasswordView(
            viewModel: viewModel,
            sendLinkAction: { [weak self] in self?.forgotPassword(viewModel) },
            backAction: { [weak self] in self?.popViewController(animated: true) }
        )

        pushViewController(UIHostingController(rootView: view), animated: true)
    }

    private func forgotPassword(_ model: ForgotPasswordViewModel) {
        model.isProcessing = true
        Task { @MainActor in
            do {
                defer {
                    model.isProcessing = false
                }
                try await Auth.auth().sendPasswordReset(withEmail: model.email)
                showForgotPasswordConfirmation()
            } catch {
                let message = error._messageForAuthError()
                Logger.auth.error("forgotPassword error \(message)")
                self.showAuthenticationError(withMessage: message)
            }
        }
    }

    private func showForgotPasswordConfirmation() {
        let view = ForgotPasswordConfirmationView(
            backAction: { [weak self] in self?.popViewController(animated: true) },
            backToSignInAction: { [weak self] in
                guard let self = self else { return }
                let vcCount = self.viewControllers.count
                if vcCount >= 3 {
                    self.popToViewController(self.viewControllers[vcCount - 3], animated: true)
                } else {
                    self.popViewController(animated: true)
                }
            }
        )
        pushViewController(UIHostingController(rootView: view), animated: true)
    }
}

// MARK: - sign up

extension AuthFlowController {
    private func showEmailAndPasswordSignUpView() {
        let viewModel = EmailSignUpViewModel()

        let emailSignUpView = EmailSignUpView(
            viewModel: viewModel,
            continueAction: { [weak self] in self?.signUp(byEmailAndPassword: viewModel) },
            backAction: { [weak self] in self?.popViewController(animated: true) }
        )

        let emailSignUpVC = UIHostingController<EmailSignUpView>(rootView: emailSignUpView)

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
                if !user.isEmailVerified {
                    try await user.sendEmailVerification()
                    self.showAwaitEmailVerificationView()
                } else {
                    let userId = try await user._getUserId()
                    onAuthenticated(userId)
                }
            } catch {
                let message = error._messageForAuthError()
                Logger.auth.error("createUser error \(message)")
                self.showAuthenticationError(withMessage: message)
            }
        }
    }
}

// MARK: - await email verification

extension AuthFlowController {
    private func showAwaitEmailVerificationView() {
        let vc = setupAwaitEmailVerificationView()
        pushViewController(vc, animated: true)
    }

    /// Creates the view and starts the timer for checking if user is verified
    private func setupAwaitEmailVerificationView() -> UIViewController {
        let viewModel = AwaitEmailVerificationViewModel()
        let awaitEmailVerificationView = AwaitEmailVerificationView(
            viewModel: viewModel,
            resendAction: { [weak self] in self?.resendEmailVerification(viewModel) },
            backAction: { [weak self] in
                // This is a sign out as user may decide to login as someone else...
                // And there's no way around email verification...
                self?.signOutFromAwaitEmailVerification()
                self?.popToRootViewController(animated: true)
            }
        )
        let awaitEmailVerificationVC = UIHostingController<AwaitEmailVerificationView>(
            rootView: awaitEmailVerificationView
        )
        checkEmailVerifiedTimer = Timer.scheduledTimer(
            timeInterval: 2,
            target: self,
            selector: #selector(checkEmailVerified),
            userInfo: nil,
            repeats: true
        )
        return awaitEmailVerificationVC
    }

    private func signOutFromAwaitEmailVerification() {
        checkEmailVerifiedTimer?.invalidate()
        do {
            try Auth.auth().signOut()
        } catch {
            let message = error._messageForAuthError()
            Logger.auth.error("signOutFromAwaitEmailVerification error \(message)")
            showAuthenticationError(withMessage: message)
        }
    }

    /// After the user email is verified
    private func proceedFromAwaitEmailVerification(_ user: FirebaseUser) {
        checkEmailVerifiedTimer?.invalidate()
        Task { @MainActor in
            do {
                let userId = try await user._getUserId()
                onAuthenticated(userId)
            } catch {
                let message = error._messageForAuthError()
                Logger.auth.error("proceedFromAwaitEmailVerification error \(message)")
                self.showAuthenticationError(withMessage: message)
            }
        }
    }

    private func resendEmailVerification(_ viewModel: AwaitEmailVerificationViewModel) {
        viewModel.isProcessing = true
        Task { @MainActor in
            do {
                defer {
                    viewModel.isProcessing = false
                }
                try await Auth.auth().currentUser?.sendEmailVerification()
                ToastWindow.shared.showSuccess(text: "Email verification sent")
            } catch {
                let message = error._messageForAuthError()
                Logger.auth.error("sendEmailVerification error \(message)")
                self.showAuthenticationError(withMessage: message)
            }
        }
    }

    /// Called by a timer - poll information about user to see if email was verified in the meantime.
    /// In practice this function results in error when user verifies it's email (as Firebase Auth requires the user to sign in again) so the
    /// happy path of `proceedFromAwaitEmailVerification` is not followed
    @objc
    private func checkEmailVerified() {
        guard let user = Auth.auth().currentUser else { return }
        user.reload { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                // this means that user needs to sign in again
                let message = error._messageForAuthError()
                Logger.auth.error("checkEmailVerified, reload user error \(message)")
                self.signOutFromAwaitEmailVerification()
                self.popToRootViewController(animated: true)
            } else {
                if user.isEmailVerified {
                    self.proceedFromAwaitEmailVerification(user)
                }
            }
        }
    }
}

// MARK: - error handling

extension AuthFlowController {
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
