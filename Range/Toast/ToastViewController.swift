import Foundation
import UIKit

/// The root view controller for the `ToastWindow`.
/// Capable of displaying toast views.
class ToastViewController: UIViewController {
    weak var keyWindow: UIWindow?
    private var currentToastView: ToastView?
    /// automatically hides the toast after 5 seconds
    private var hideToastDelayer = Delayer(delayTime: 5)

    /// Initialize with the key window. It's needed to synchronize the status bar appearance from.
    init(keyWindow: UIWindow) {
        self.keyWindow = keyWindow
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Override loadView to customise view to be a passthrough view.
    override func loadView() {
        view = PassthroughView()
    }

    /// Override status bar related properties to read from the current top view controller in the key window
    override dynamic var preferredStatusBarStyle: UIStatusBarStyle {
        keyWindow?.rootViewController?._topViewController().preferredStatusBarStyle ?? .default
    }

    override var childForStatusBarStyle: UIViewController? {
        keyWindow?.rootViewController?._topViewController().childForStatusBarStyle
    }

    /// Show toast with given text and color.
    /// This will replace the previously shown toast (if any)
    /// The toast will automatically disappear after 5 seconds or when tapped.
    func showToast(text: String, color: UIColor, borderColor: UIColor? = nil) {
        let toastView = ToastView(text: text, backgroundColor: color, borderColor: borderColor)
        _hideCurrentToastView {
            self._showToastView(toastView)
        }
    }

    private func _hideCurrentToastView(completion: (() -> Void)? = nil) {
        // cancel the current scheduled toast hiding
        hideToastDelayer.cancel()
        if let currentToastView = currentToastView {
            UIView.animate(withDuration: 0.2, animations: {
                currentToastView.alpha = 0
            }) { _ in
                currentToastView.removeFromSuperview()
                self.currentToastView = nil
                completion?()
            }
        } else {
            completion?()
        }
    }

    private func _showToastView(_ toastView: ToastView) {
        toastView.isUserInteractionEnabled = true
        toastView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(toastTapped)))
        view.addSubview(toastView)
        toastView.snp.makeConstraints { make in
            make.top.equalTo(self.view.safeAreaLayoutGuide.snp.top)
            make.centerX.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(16)
            make.trailing.lessThanOrEqualToSuperview().offset(-16)
        }
        toastView.alpha = 0
        UIView.animate(withDuration: 0.2) {
            toastView.alpha = 1
        }
        currentToastView = toastView

        // schedule hiding toast
        hideToastDelayer.delay { [weak self] in
            self?._hideCurrentToastView()
        }
    }

    @objc func toastTapped() {
        _hideCurrentToastView()
    }
}
