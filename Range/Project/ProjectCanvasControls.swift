import Foundation
import Lottie
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
        case cardOnboardingView = 1008
        case locationSimulationButton = 1009
        case followMeModeButton = 1010
        case inAppUnseenItemsBadge = 1011
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
    var topViewController: TopViewController? {
        canvasContainer.children.first {
            $0.view.tag == ViewTag.topView.rawValue && $0.view.superview == self
        } as? TopViewController
    }

    /// Creates a `TopViewController` and shows it in an `animated` way
    func showTopViewController(
        iconName: String? = nil,
        title: String,
        onBack: (() -> Void)? = nil,
        showInAppFeedButton: Bool = false,
        userDataSyncState: UserDataSyncState? = nil,
        animated: Bool
    ) {
        if topViewController == nil {
            let topViewController = TopViewController(
                iconName: iconName,
                title: title,
                onBack: onBack,
                rightAction: showInAppFeedButton
                    ? UIAction(image: UIImage(systemName: "bell"), handler: { [weak self] _ in
                        UIApplication.shared.sendAction(#selector(ProjectFlowActions.showProjectInAppFeed),
                                                        to: nil, from: self, for: nil)
                    })
                    : nil,
                userDataSyncState: userDataSyncState
            )
            if let userDataSyncState {
                topViewController.onDataSyncBannerTapped = { [weak self] in
                    guard let self else { return }
                    _dataSyncInfoCard(userDataSyncState.state)
                        .installAndShowCard(in: self.canvasContainer, inView: self.canvasContainer.controls)
                }
            }
            canvasContainer.add(childController: topViewController, toView: self)
            topViewController.view.tag = ViewTag.topView.rawValue

            if animated {
                topViewController.view.snp.makeConstraints { make in
                    make.leading.trailing.equalToSuperview()
                    make.bottom.equalTo(self.snp.top)
                }
                layoutIfNeeded()
            }
        }
        guard let topViewController else { return }

        if animated {
            UIView.animate(withDuration: 0.2) {
                topViewController.view.snp.remakeConstraints { make in
                    make.leading.trailing.equalToSuperview()
                    make.top.equalToSuperview()
                }
                self.layoutIfNeeded()
            }
        } else {
            topViewController.view.snp.remakeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.top.equalToSuperview()
            }
            layoutIfNeeded()
        }
    }

    /// Hides the `TopViewController` in an animated way
    func hideTopViewController(animated: Bool) {
        guard let topViewController else { return }
        if animated {
            UIView.animate(withDuration: 0.2, animations: {
                topViewController.view.snp.remakeConstraints { make in
                    make.leading.trailing.equalToSuperview()
                    make.bottom.equalTo(self.snp.top)
                }
                self.layoutIfNeeded()
            })
        } else {
            topViewController.view.snp.remakeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.bottom.equalTo(self.snp.top)
            }
        }
    }

    /// Access to currently showing in-ap unseen items badge view
    var inAppUnseenItemsBadge: BadgeView? {
        guard let topViewController else { return nil }
        return topViewController.view.subviews.first {
            $0.tag == ViewTag.inAppUnseenItemsBadge.rawValue
        } as? BadgeView
    }

    func updateInAppUnseenItemsBadge(_ knockFeedModel: KnockFeedModel) {
        let unseenCount = knockFeedModel.feed.meta.unseen_count
        // hide the badge if there's 0 unseen items
        guard unseenCount > 0 else {
            if let inAppUnseenItemsBadge {
                inAppUnseenItemsBadge.alpha = 0.0
            }
            return
        }

        guard let topViewController, let inAppButton = topViewController.rightButton else { return }
        if inAppUnseenItemsBadge == nil {
            let badge = BadgeView()
            badge.backgroundColor = .Special_01
            badge.contentInsets = UIEdgeInsets(top: 2, left: 2, bottom: 2, right: 2)
            badge.textColor = .white
            badge.font = .systemFont(ofSize: 8)
            badge.isUserInteractionEnabled = false
            badge.tag = ViewTag.inAppUnseenItemsBadge.rawValue
            // add to topViewController.view and not inAppButton, as it causes rendering issues with inappbutton
            // the badge is ultimately rendered below the button image view ... (?)
            topViewController.view.addSubview(badge)
            badge.snp.makeConstraints { make in
                make.centerX.equalTo(inAppButton.snp.centerX).offset(-8)
                make.centerY.equalTo(inAppButton.snp.centerY).offset(-8)
            }
        }

        guard let inAppUnseenItemsBadge else { return }
        inAppUnseenItemsBadge.alpha = 1.0
        inAppUnseenItemsBadge.text = unseenCount > 9 ? "9⁺" : String(unseenCount)
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

        // fadeIn only when the alpha is below the requested or the text changes (then "blink" the view)
        let shouldAnimate = animated &&
            (topIndicatorView.alpha < topIndicatorViewFullOpacity || topIndicatorView.text != text)

        topIndicatorView.text = text

        if shouldAnimate {
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

// MARK: - onboarding

extension ProjectCanvasControls {
    /// Access to currently showing card onboarding animation view
    var cardOnboardingView: UIView? {
        subviews.first { $0.tag == ViewTag.cardOnboardingView.rawValue }
    }

    func showCardOnboardingView(aboveView: UIView) {
        let overlay = PassthroughGradientView()
        overlay.tag = ViewTag.cardOnboardingView.rawValue
        overlay.backgroundColor = .clear
        // top to bottom gradient
        overlay.gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        overlay.gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        overlay.gradientLayer.colors = [
            UIColor.black.withAlphaComponent(0.0).cgColor,
            UIColor.black.withAlphaComponent(0.6).cgColor,
        ]
        addSubview(overlay)
        overlay.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        let label = UILabel()
        label.text = String(localized: "Swipe up to view more features")
        label.textColor = .white
        label.font = .preferredFont(forTextStyle: .caption1)
        label.adjustsFontForContentSizeCategory = true
        overlay.addSubview(label)
        label.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(aboveView.snp.top).offset(-12)
        }

        let cardOnboardingView = LottieAnimationView(asset: "canvas card onboarding animation")
        overlay.addSubview(cardOnboardingView)
        cardOnboardingView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(label.snp.top).offset(-12)
        }
        cardOnboardingView.loopMode = .loop
        cardOnboardingView.play()
    }

    func hideCardOnboardingView() {
        guard let view = cardOnboardingView else { return }
        UIView.animate(withDuration: 0.2,
                       animations: {
                           view.alpha = 0
                       }, completion: { _ in
                           view.removeFromSuperview()
                       })
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

// MARK: - follow me mode

extension ProjectCanvasControls {
    /// Access to currently showing button, or nil if not showing
    var followMeModeButton: RoundShadowButton? {
        subviews.first { $0.tag == ViewTag.followMeModeButton.rawValue } as? RoundShadowButton
    }

    func showFollowMeModeButton(aboveView: UIView) {
        let button = RoundShadowButton(
            image: UIImage(systemName: "location") ?? UIImage(),
            selectedImage: UIImage(systemName: "location.fill")
        )
        button.tag = ViewTag.followMeModeButton.rawValue
        button.addTarget(self, action: #selector(followMeModeButtonTapped), for: .touchUpInside)
        addSubview(button)
        button.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(12)
            make.bottom.equalTo(aboveView.snp.top).offset(-12)
        }
    }

    func hideFollowMeModeButton() {
        followMeModeButton?.removeFromSuperview()
    }

    @objc private func followMeModeButtonTapped() {
        UIApplication.shared.sendAction(#selector(ProjectFlowActions.toggleFollowMeModeAction),
                                        to: nil, from: locationSimulationButton, for: nil)
    }
}

// MARK: - location simulation

extension ProjectCanvasControls {
    /// Access to currently showing button, or nil if not showing
    var locationSimulationButton: RoundShadowButton? {
        subviews.first { $0.tag == ViewTag.locationSimulationButton.rawValue } as? RoundShadowButton
    }

    func showLocationSimulationButton(aboveView: UIView) {
        let button =
            RoundShadowButton(image: UIImage(systemName: "dot.circle.and.hand.point.up.left.fill") ?? UIImage())
        button.tag = ViewTag.locationSimulationButton.rawValue
        button.addTarget(self, action: #selector(locationSimulationButtonTapped), for: .touchUpInside)
        addSubview(button)
        button.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(12)
            make.bottom.equalTo(aboveView.snp.top).offset(-12)
        }
    }

    func hideLocationSimulationButton() {
        guard let button = locationSimulationButton else { return }
        button.removeFromSuperview()
    }

    @objc private func locationSimulationButtonTapped() {
        UIApplication.shared.sendAction(#selector(ProjectFlowActions.toggleLocationSimulationAction),
                                        to: nil, from: locationSimulationButton, for: nil)
    }
}
