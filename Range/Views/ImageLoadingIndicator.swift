import Foundation
import Kingfisher
import UIKit

/// Indicator used when loading images using Kingfisher
/// Instead of using kf `.activity` indicator type we need a custom one to change the activity indicator color
struct ImageLoadingIndicator: Indicator {
    private let activityIndicatorView: UIActivityIndicatorView

    var view: IndicatorView {
        activityIndicatorView
    }

    func startAnimatingView() {
        activityIndicatorView.startAnimating()
        activityIndicatorView.isHidden = false
    }

    func stopAnimatingView() {
        activityIndicatorView.stopAnimating()
        activityIndicatorView.isHidden = true
    }

    func sizeStrategy(in _: KFCrossPlatformImageView) -> IndicatorSizeStrategy {
        .intrinsicSize
    }

    init() {
        activityIndicatorView = UIActivityIndicatorView(style: .medium)
        activityIndicatorView.color = .Pink_03
    }
}
