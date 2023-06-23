import Foundation
import UIKit

/// Custom window for displaying toasts.
/// Displays on top of the key window.
/// It steals the status bar and orientation management from key window but its root view controller (`ToastViewController`)
/// synchronizes this data from the key window (toast window/view controller should not change the app status bar, etc.)
class ToastWindow: UIWindow {
    static let shared = ToastWindow()

    private init() {
        super.init(frame: UIScreen.main.bounds)
    }

    /// To show the toast window.
    /// Should be called after the key window `makeKeyAndVisible`
    func showForKeyWindow(_ window: UIWindow) {
        guard let scene = window.windowScene else { return }
        rootViewController = ToastViewController(keyWindow: window)
        windowScene = scene
        isHidden = false
    }

    /// This is a hack to forse status bar appearance update. Status bar appearance is driven by top most window (which
    /// is this window) but we want it to be based on the requested appearance of the top view controller in the key window.
    /// On some screens transitions it works by itself but sometimes we need to kick it manually when transitioning
    /// between view controllers in the app.
    func updateStatusBarAppearance() {
        rootViewController?.setNeedsStatusBarAppearanceUpdate()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Passing all touches to the next view (if any), in the view stack.
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard let rootVC = rootViewController else { return false }
        return rootVC.view.subviews.contains { subview in
            subview.hitTest(convert(point, to: subview), with: event) != nil
        }
    }

    /// Show toast with given text and color.
    /// This will replace the previously shown toast (if any)
    /// The toast will automatically disappear after 5 seconds or when tapped.
    private func showToast(iconName: String? = nil, text: String, color: UIColor, borderColor: UIColor? = nil) {
        (rootViewController as? ToastViewController)?.showToast(
            iconName: iconName,
            text: text,
            color: color,
            borderColor: borderColor
        )
    }

    /// Helper function for showing toast with predefined color for error.
    func showError(text: String) {
        showToast(text: text, color: .Red_03, borderColor: .Red_04)
    }

    /// Helper function for showing toast with predefined color for warning.
    func showWarning(text: String) {
        showToast(text: text, color: .Orange_03, borderColor: .Orange_04)
    }

    /// Helper function for showing toast with predefined color for success.
    func showSuccess(iconName: String? = nil, text: String) {
        showToast(iconName: iconName, text: text, color: .Green_03, borderColor: .Green_03)
    }
}
