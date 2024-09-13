import Foundation
import UIKit

/// Gesture recognizer that accepts a closure
final class BindableGestureRecognizer: UITapGestureRecognizer {
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
        super.init(target: nil, action: nil)
        self.addTarget(self, action: #selector(execute))
    }

    @objc private func execute() {
        action()
    }
}
