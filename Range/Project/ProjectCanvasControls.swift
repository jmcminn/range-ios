import Foundation
import UIKit

/// A controls view added to CanvasContainerViewController.controls to handle display of common project views.
/// Each flow controller adds it's own ProjectCanvasControls, so the views dont collide by tag between different flow controllers.
class ProjectCanvasControls: PassthroughView {
    /// Tag for uniquely identifying subviews of canvas container (assuming that each view is only added once to the canvas container)
    fileprivate enum ViewTag: Int {
        case topView = 11111
        case panAndZoomIndicatorView = 22222
        case canvasSelectorButton = 33333
        case canvasSourceSelectorButton = 44444
        case canvasFiltersButton = 55555
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
            backgroundColor: .Neutral_10
        )
        panAndZoomIndicatorView.tag = ViewTag.panAndZoomIndicatorView.rawValue
        addSubview(panAndZoomIndicatorView)
        panAndZoomIndicatorView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
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
        let button = RoundShadowButton(image: UIImage(systemName: "line.3.horizontal.decrease.circle") ?? UIImage())
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
}
