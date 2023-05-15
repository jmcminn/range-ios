import Foundation
import UIKit

/// A controls view added to CanvasContainerViewController.controls to handle display of common project views.
/// Each flow controller adds it's own ProjectCanvasControls, so the views dont collide by tag between different flow controllers.
class ProjectCanvasControls: PassthroughView {
    /// Tag for uniquely identifying subviews of canvas container (assuming that each view is only added once to the canvas container)
    fileprivate enum ViewTag: Int {
        case topView = 1001
        case topIndicatorView = 1002
        case panAndZoomIndicatorView = 1003
        case canvasSelectorButton = 1004
        case canvasSourceSelectorButton = 1005
        case canvasFiltersButton = 1006
        case canvasFiltersIndicatorBadge = 1007
    }

    unowned let canvasContainer: CanvasContainerViewController

    init(canvasContainer: CanvasContainerViewController) {
        self.canvasContainer = canvasContainer
        super.init(frame: .zero)

        canvasContainer.controls.addSubview(self)
        snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - TopViewController

extension ProjectCanvasControls {
    /// Access to currently showing top VC, or nil if not showing
    var topViewController: UIViewController? {
        canvasContainer.children.first { $0.view.tag == ViewTag.topView.rawValue && $0.view.superview == self }
    }

    /// Creates a `TopViewController` and shows it in an `animated` way
    func showTopViewController(iconName: String? = nil, title: String, onBack: (() -> Void)? = nil, animated: Bool) {
        let topViewController = TopViewController(iconName: iconName, title: title, onBack: onBack)
        canvasContainer.add(childController: topViewController, toView: self)
        topViewController.view.tag = ViewTag.topView.rawValue

        if animated {
            topViewController.view.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.bottom.equalTo(self.snp.top)
            }
            layoutIfNeeded()
            UIView.animate(withDuration: 0.2) {
                topViewController.view.snp.remakeConstraints { make in
                    make.leading.trailing.equalToSuperview()
                    make.top.equalToSuperview()
                }
                self.layoutIfNeeded()
            }
        } else {
            topViewController.view.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.top.equalToSuperview()
            }
            layoutIfNeeded()
        }
    }

    /// Hides the `TopViewController` in an animated way
    func hideTopViewController(animated: Bool) {
        guard let viewController = topViewController else { return }
        if animated {
            UIView.animate(withDuration: 0.2, animations: {
                viewController.view.snp.remakeConstraints { make in
                    make.leading.trailing.equalToSuperview()
                    make.bottom.equalTo(self.snp.top)
                }
                self.layoutIfNeeded()
            }, completion: { [weak self] _ in
                self?.canvasContainer.remove(childController: viewController)
            })
        } else {
            canvasContainer.remove(childController: viewController)
        }
    }
}

// MARK: - topIndicatorView

extension ProjectCanvasControls {
    /// Access to currently showing topIndicatorView, or nil if not showing
    var topIndicatorView: TopIndicatorView? {
        subviews.first { $0.tag == ViewTag.topIndicatorView.rawValue } as? TopIndicatorView
    }

    /// topIndicatorView is always partially transparent
    private var topIndicatorViewFullOpacity: CGFloat { 0.6 }

    /// Adds the indicator view to controls and displays below the topViewController
    func showTopIndicatorView(text: String, animated: Bool) {
        guard let topView = topViewController?.view else { return }

        if self.topIndicatorView == nil {
            let topIndicatorView = TopIndicatorView()
            topIndicatorView.tag = ViewTag.topIndicatorView.rawValue
            insertSubview(topIndicatorView, belowSubview: topView)
            topIndicatorView.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.top.equalTo(topView.snp.bottom)
            }
        }
        guard let topIndicatorView = topIndicatorView else { return }
        topIndicatorView.text = text

        if animated {
            topIndicatorView.alpha = 0.0
            fadeInTopIndicatorView()
        } else {
            topIndicatorView.alpha = topIndicatorViewFullOpacity
        }
    }

    /// Slides the indicator view behind the topViewController
    func fadeOutTopIndicatorView(completion: (() -> Void)? = nil) {
        guard let topIndicatorView = topIndicatorView else { return }
        UIView.animate(withDuration: 0.2, animations: {
            topIndicatorView.alpha = 0.0
        }) { _ in
            completion?()
        }
    }

    /// Slides the indicator view down so it's visible again
    func fadeInTopIndicatorView(completion: (() -> Void)? = nil) {
        guard let topIndicatorView = topIndicatorView else { return }
        UIView.animate(withDuration: 0.2, animations: {
            topIndicatorView.alpha = self.topIndicatorViewFullOpacity
        }) { _ in
            completion?()
        }
    }

    /// Hides (and removes) the `TopViewController` in an animated way
    func hideTopIndicatorView(animated: Bool) {
        guard let topIndicatorView = topIndicatorView else { return }
        if animated {
            fadeOutTopIndicatorView {
                topIndicatorView.removeFromSuperview()
            }
        } else {
            topIndicatorView.removeFromSuperview()
        }
    }
}

// MARK: - panAndZoomIndicator

extension ProjectCanvasControls {
    /// Access to currently showing panAndZoomIndicatorView, or nil if not showing
    var panAndZoomIndicatorView: UIView? {
        subviews.first { $0.tag == ViewTag.panAndZoomIndicatorView.rawValue }
    }

    /// Show panAndZoomIndicatorView
    func showPanAndZoomIndicatorView(aboveView: UIView) {
        let panAndZoomIndicatorView = ToastView(
            iconName: "hand.point.up.left",
            text: "Pan and zoom to adjust the location",
            backgroundColor: .Neutral_10, blurBackground: true
        )
        panAndZoomIndicatorView.tag = ViewTag.panAndZoomIndicatorView.rawValue
        addSubview(panAndZoomIndicatorView)
        anchorPanAndZoomIndicatorView(aboveView: aboveView)
    }

    func anchorPanAndZoomIndicatorView(aboveView: UIView) {
        guard let panAndZoomIndicatorView = panAndZoomIndicatorView else { return }
        panAndZoomIndicatorView.snp.remakeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.trailing.lessThanOrEqualToSuperview().offset(-72) // leave space for FABs on the right
            make.bottom.equalTo(aboveView.snp.top).offset(-12)
        }
    }

    /// Hide panAndZoomIndicatorView if it's currently shown
    func hidePanAndZoomIndicatorView(animated: Bool) {
        guard let view = panAndZoomIndicatorView else { return }
        if animated {
            UIView.animate(withDuration: 0.2,
                           animations: {
                               view.alpha = 0
                           }, completion: { _ in
                               view.removeFromSuperview()
                           })
        } else {
            view.removeFromSuperview()
        }
    }
}

// MARK: - canvasSelectorButton

extension ProjectCanvasControls {
    /// Access to currently showing canvas selector button, or nil if not showing
    var canvasSelectorButton: UIView? {
        subviews.first { $0.tag == ViewTag.canvasSelectorButton.rawValue }
    }

    func showCanvasSelectorButton(aboveView: UIView) {
        let button = RoundShadowButton(image: UIImage(systemName: "square.3.layers.3d") ?? UIImage())
        button.tag = ViewTag.canvasSelectorButton.rawValue
        button.addTarget(self, action: #selector(canvasSelectorButtonTapped), for: .touchUpInside)
        addSubview(button)
        button.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(12)
            make.bottom.equalTo(aboveView.snp.top).offset(-12)
        }
    }

    func hideCanvasSelectorButton() {
        guard let button = canvasSelectorButton else { return }
        button.removeFromSuperview()
    }

    @objc private func canvasSelectorButtonTapped() {
        UIApplication.shared.sendAction(#selector(ProjectFlowActions.selectCanvasAction),
                                        to: nil, from: canvasSelectorButton, for: nil)
    }
}

// MARK: - canvasSourceSelectorButton

extension ProjectCanvasControls {
    /// Access to currently showing canvas source selector button, or nil if not showing
    var canvasSourceSelectorButton: UIView? {
        subviews.first { $0.tag == ViewTag.canvasSourceSelectorButton.rawValue }
    }

    func showCanvasSourceSelectorButton(aboveView: UIView) {
        let button = RoundShadowButton(image: UIImage(systemName: "map") ?? UIImage())
        button.addTarget(
            self,
            action: #selector(canvasSourceSelectorButtonTapped),
            for: .touchUpInside
        )
        button.tag = ViewTag.canvasSourceSelectorButton.rawValue
        addSubview(button)
        button.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(12)
            make.bottom.equalTo(aboveView.snp.top).offset(-12)
        }
    }

    func hideCanvasSourceSelectorButton() {
        guard let button = canvasSourceSelectorButton else { return }
        button.removeFromSuperview()
    }

    @objc private func canvasSourceSelectorButtonTapped() {
        UIApplication.shared.sendAction(#selector(ProjectFlowActions.selectCanvasSourceAction),
                                        to: nil, from: canvasSourceSelectorButton, for: nil)
    }
}

// MARK: - canvasFiltersButton

extension ProjectCanvasControls {
    /// Access to currently showing canvas source selector button, or nil if not showing
    var canvasFiltersButton: UIView? {
        subviews.first { $0.tag == ViewTag.canvasFiltersButton.rawValue }
    }

    func showCanvasFiltersButton(aboveView: UIView) {
        let button = RoundShadowButton(image: UIImage(named: "filter.search") ?? UIImage())
        button.tag = ViewTag.canvasFiltersButton.rawValue
        button.addTarget(self, action: #selector(canvasFiltersButtonTapped), for: .touchUpInside)
        addSubview(button)
        button.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(12)
            make.bottom.equalTo(aboveView.snp.top).offset(-12)
        }
    }

    @objc private func canvasFiltersButtonTapped() {
        UIApplication.shared.sendAction(#selector(ProjectFlowActions.selectCanvasFiltersAction),
                                        to: nil, from: canvasSourceSelectorButton, for: nil)
    }

    /// Access to currently showing canvas filters indicators badge, or nil if not showing
    var canvasFiltersIndicatorBadge: BadgeView? {
        canvasFiltersButton?.subviews
            .first { $0.tag == ViewTag.canvasFiltersIndicatorBadge.rawValue } as? BadgeView
    }

    func showCanvasFiltersIndicatorBadge() {
        guard let canvasFiltersButton = canvasFiltersButton else {
            fatalError("showCanvasFiltersIndicatorBadge called when canvasFiltersButton is not shown")
        }
        let badge = BadgeView()
        badge.backgroundColor = .systemGreen
        badge.contentInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        badge.textColor = .Neutral_10
        badge.font = .systemFont(ofSize: 11, weight: .bold)
        badge.isUserInteractionEnabled = false
        badge.tag = ViewTag.canvasFiltersIndicatorBadge.rawValue
        canvasFiltersButton.addSubview(badge)
        badge.snp.makeConstraints { make in
            make.centerX.equalToSuperview().offset(16)
            make.centerY.equalToSuperview().offset(-16)
        }
    }
}
