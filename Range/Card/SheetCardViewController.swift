import Foundation
import UIKit

/// Base class for non modal card view controllers that have an icon, a title and a close button at the top.
/// This card only supports .min position (0 height) and .max position.
/// By default this card closes when minimized, when the overlay is tapped or when the close button is tapped
class SheetCardViewController: UIViewController, NonModalCardCoordinating, CardPresentable, CardDraggingDelegate,
    UIScrollViewDelegate
{
    private let cardConfig: CardConfiguration
    private let autoDismiss: Bool
    var cardDragging: NonModalCardDragging?
    private var cardDraggingDelegateId: UUID?
    /// This card presents itself in given vc
    private(set) weak var presentingVC: UIViewController?

    /// The view containing the slider, icon, title, subtitle and close button
    /// It also has some bottom margin added, so any sheet content view can be added directly below it
    let sheetHeaderView = UIView()
    private(set) var closeButton: UIButton!
    private(set) var titleIcon: UIImageView?
    private(set) var titleLabel: UILabel?
    private(set) var subtitleLabel: UILabel?
    private(set) var descriptionLabel: UILabel?
    private(set) var searchView: SearchView! // not nil if initiated with showSearchView = true
    private var sheetHeaderStroke: UIView?
    private var sheetHeaderShadowEnabled: Bool = false

    /// a view below content to cover the space visible when dragging up past the max height
    private(set) var bottomView = UIView()

    /// Invoked when the sheet is dismissed by tapping close button, the overlay or dragging the card down to min position
    var onClose: (() -> Void)?

    /// Initializer
    /// - Parameters:
    ///   - autoDismiss: by default the card is dismissed when closed, for dismissing manually (in response to onClose) set to false
    init(
        icon: UIImage?,
        title: String?,
        subtitle: String? = nil,
        description: String? = nil,
        showSearchView: Bool = false,
        onClose: (() -> Void)? = nil,
        cardConfig: CardConfiguration = CardConfiguration(initialCardPosition: .max, showOverlay: true),
        autoDismiss: Bool = true
    ) {
        self.cardConfig = cardConfig
        self.autoDismiss = autoDismiss
        super.init(nibName: nil, bundle: nil)

        self.onClose = onClose

        if let icon = icon {
            setupTitleIcon(image: icon)
        }
        if let title = title {
            setupTitleLabel(title: title)
        }
        if let subtitle = subtitle {
            setupSubtitleLabel(text: subtitle)
        }
        if let description = description {
            setupDescriptionLabel(text: description)
        }
        if showSearchView {
            searchView = SearchView()
        }
    }

    /// Adds the stroke to the bottom of the sheet header view
    func addSheetHeaderStroke() {
        guard sheetHeaderStroke == nil else { return }

        let headerStroke = UIView()
        headerStroke.backgroundColor = .dynamic(.Neutral_07)
        sheetHeaderView.addSubview(headerStroke)
        headerStroke.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(1)
        }
        sheetHeaderStroke = headerStroke
    }

    /// Adds the shadow to the sheet header that is shown when the driving scroll view is offset.
    /// It is illegal to call this function if the driving scroll view is nil
    func addSheetHeaderShadowBasedOnDrivingScrollView() {
        guard let scrollView = drivingScrollView() else {
            fatalError("addSheetHeaderShadowBasedOnDrivingScrollView called but drivingScrollView() returned nil")
        }
        guard sheetHeaderShadowEnabled == false else { return }
        sheetHeaderShadowEnabled = true
        scrollView.forwardDelegateInvocations(to: self)
    }

    var roundedShadowView: RoundShadowView {
        view as! RoundShadowView
    }

    var containerView: UIView {
        roundedShadowView.containerView
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = RoundShadowView(cornerRadius: 24)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        containerView.backgroundColor = .dynamic(.Neutral_10)

        setupSheetHeaderView()
        containerView.addSubview(sheetHeaderView)
        sheetHeaderView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(69).priority(.high)
        }

        sheetHeaderView.installSliderView()

        setupCloseButton()
        sheetHeaderView.addSubview(closeButton)
        closeButton.snp.makeConstraints { make in
            make.width.height.equalTo(32)
            make.trailing.equalToSuperview().inset(16)
            make.top.equalToSuperview().offset(21)
            make.bottom.lessThanOrEqualToSuperview().offset(-16)
        }

        if let titleIcon = titleIcon {
            sheetHeaderView.addSubview(titleIcon)
            titleIcon.snp.makeConstraints { make in
                make.centerY.equalTo(closeButton.snp.centerY)
                make.leading.equalTo(16)
            }
        }
        if let titleLabel = titleLabel {
            sheetHeaderView.addSubview(titleLabel)
            titleLabel.snp.makeConstraints { make in
                make.centerY.equalTo(closeButton.snp.centerY)
                if titleIcon != nil {
                    make.leading.equalTo(titleIcon!.snp.trailing).offset(8)
                } else {
                    make.leading.equalTo(16)
                }
            }
            if let subtitleLabel = subtitleLabel {
                sheetHeaderView.addSubview(subtitleLabel)
                subtitleLabel.snp.makeConstraints { make in
                    make.leading.equalTo(titleLabel)
                    make.trailing.equalToSuperview().inset(16)
                    make.top.equalTo(titleLabel.snp.bottom).offset(4)
                    make.bottom.lessThanOrEqualToSuperview().offset(-16)
                }
            }
        }
        // icon, title, subtitle and closeButton layout is quite complicated so it's not part of the
        // stack view (because closeButton defines the sheetHeader height if there's not subtitle)
        // What's below is a vertical stack view
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.backgroundColor = containerView.backgroundColor
        if let descriptionLabel = descriptionLabel {
            // dont compress label so the UIStackView height is more important than the hardcoded
            // sheetHeader height constraint
            descriptionLabel.setContentCompressionResistancePriority(.required, for: .vertical)
            stackView.addArrangedSubview(descriptionLabel)
        }
        if let searchView = searchView {
            if stackView.arrangedSubviews.isEmpty {
                // if this is the first view we want a little more spacing (descriptionLabel wants only 8, which search 16)
                let spacer = UIView()
                stackView.addArrangedSubview(spacer)
                stackView.setCustomSpacing(8, after: spacer)
            }
            searchView.setContentCompressionResistancePriority(.required, for: .vertical)
            stackView.addArrangedSubview(searchView)
            searchView.snp.makeConstraints { make in
                make.height.equalTo(40)
            }
        }
        if !stackView.arrangedSubviews.isEmpty {
            sheetHeaderView.addSubview(stackView)
            stackView.snp.makeConstraints { make in
                if let subtitleLabel = subtitleLabel {
                    make.top.equalTo(subtitleLabel.snp.bottom).offset(8)
                } else {
                    make.top.equalTo(closeButton.snp.bottom).offset(8)
                }
                make.leading.trailing.bottom.equalToSuperview().inset(16)
            }
        }

        bottomView.backgroundColor = .dynamic(.Neutral_10)
        // added to view (rounded view) as the containerView has a layer mask
        // and bottom view is added outside of its bounds
        view.addSubview(bottomView)
        bottomView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(view.snp.bottom).offset(-1)
            // magic number, just enough so the user won't drag higher than that (beyond the max height)
            make.height.equalTo(500)
        }
        updateColors()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateColors()
        }
        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            // animate the card to adjust for the possible height change because of font size change
            guard let cardDragging = cardDragging else { return }
            cardDragging.setPosition(cardDragging.position, withVelocity: 0)
        }
    }

    func updateColors() {
        let darkMode = traitCollection.userInterfaceStyle == .dark
        if darkMode {
            view.setShadowWithFigmaValues(y: -6, blur: 10, opacity: 0.2)
        } else {
            view.setShadowWithFigmaValues(y: -3, blur: 6, opacity: 0.05)
        }
        // stroke not visible in dark mode (same color as background)
        roundedShadowView.topStrokeColor = darkMode ? .Neutral_10 : .Neutral_04
        updateSheetHeaderShadow()
    }

    func scrollViewDidScroll(_: UIScrollView) {
        updateSheetHeaderShadow()
    }

    /// updates shadow color based on the interface style and visibility based on the `bottomStrokeVisible`
    private func updateSheetHeaderShadow() {
        guard sheetHeaderShadowEnabled else { return }
        guard let scrollView = drivingScrollView() else { return }
        let shadowVisible = scrollView.contentOffset.y > 0
        if shadowVisible {
            let darkMode = traitCollection.userInterfaceStyle == .dark
            if darkMode {
                sheetHeaderView.setShadowWithFigmaValues(x: 0, y: 6, blur: 10, opacity: 0.1)
            } else {
                sheetHeaderView.setShadowWithFigmaValues(x: 0, y: 3, blur: 6, opacity: 0.1)
            }
            // make the shadow height = 10 points, so the top part of the shadow is not visible
            // (the path covers bottom part of the view only)
            // This only works if the view is actually higher than 10 points. But if it's lower
            // then the shadow with no shadowPath would not be shown (for view that has 0 height)
            // so we still need to "cover" this view from top with another view (in a view that's
            // adding this view controller as a child)
            sheetHeaderView.layer.shadowPath = UIBezierPath(rect: CGRect(x: 0,
                                                                         y: sheetHeaderView.bounds.maxY - 10,
                                                                         width: sheetHeaderView.bounds.width,
                                                                         height: 10)).cgPath
        } else {
            sheetHeaderView.layer.shadowOpacity = 0
        }
    }

    // MARK: Views

    private func setupSheetHeaderView() {
        sheetHeaderView.backgroundColor = containerView.backgroundColor
        sheetHeaderView.setContentHuggingPriority(.required, for: .vertical)
    }

    private func setupTitleIcon(image: UIImage) {
        let imageConfig = UIImage.SymbolConfiguration(textStyle: .body)
            .applying(UIImage.SymbolConfiguration(weight: .bold))
        titleIcon = UIImageView(image: image.withRenderingMode(.alwaysTemplate).withConfiguration(imageConfig))
        titleIcon!.tintColor = .dynamic(.Neutral_04)
    }

    private func setupTitleLabel(title: String) {
        titleLabel = UILabel()
        titleLabel!.text = title
        titleLabel!.textColor = .dynamic(.Neutral_04)
        titleLabel!.font = UIFont._preferredFont(forTextStyle: .body, symbolicTraits: .traitBold)
        titleLabel!.adjustsFontForContentSizeCategory = true
    }

    private func setupSubtitleLabel(text: String) {
        subtitleLabel = UILabel()
        subtitleLabel!.text = text
        subtitleLabel!.textColor = .dynamic(.Neutral_05)
        subtitleLabel!.font = UIFont.preferredFont(forTextStyle: .subheadline)
        subtitleLabel!.numberOfLines = 0
        subtitleLabel!.lineBreakMode = .byWordWrapping
        subtitleLabel!.adjustsFontForContentSizeCategory = true
    }

    private func setupDescriptionLabel(text: String) {
        descriptionLabel = UILabel()
        descriptionLabel!.text = text
        descriptionLabel!.textColor = .dynamic(.Neutral_05)
        descriptionLabel!.font = UIFont.preferredFont(forTextStyle: .subheadline)
        descriptionLabel!.numberOfLines = 0
        descriptionLabel!.lineBreakMode = .byWordWrapping
        descriptionLabel!.adjustsFontForContentSizeCategory = true
    }

    private func setupCloseButton() {
        closeButton = ButtonWithTapAreaInsets(
            configuration: UIButton.Configuration.closeButton(),
            primaryAction: UIAction(image: UIImage(systemName: "xmark")) { [weak self] _ in
                guard let self = self else { return }
                if self.autoDismiss { self.dismissCard() }
                self.onClose?()
            }
        )
        .withTapAreaInsets(UIEdgeInsets(top: -4, left: -4, bottom: -4, right: -4))
    }

    // MARK: - card presentable

    func height(forContainer containerView: UIView, cardPosition: CardPosition) -> CGFloat {
        if cardPosition == .min {
            return 0
        }
        if cardPosition == .medium {
            return -1 // not supported
        }

        view.layoutIfNeeded()
        let height: CGFloat
        if let subtitleLabel = descriptionLabel {
            let fittingSize = CGSize(
                width: containerView.bounds.width - 32,
                height: UIView.layoutFittingCompressedSize.height
            )
            let subtitleHeight = subtitleLabel.systemLayoutSizeFitting(
                fittingSize,
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .defaultLow
            ).height
            height = 61.0 + subtitleHeight + 16.0
        } else {
            height = 69.0
        }
        return height
    }

    /// Provide some implementation that returns `nil` so the subclasses can override
    func drivingScrollView() -> UIScrollView? {
        nil
    }

    // MARK: - card presentation

    /// Convenience function for installing card in given `presentingVC` and showing the card
    @discardableResult func installAndShowCard(in presentingVC: UIViewController, inView: UIView? = nil) -> Self {
        presentingVC.installCard(cardViewController: self, inView: inView, cardConfig: cardConfig)
        cardDraggingDelegateId = cardDragging?.addDelegate(self)
        showCard(animated: true)
        self.presentingVC = presentingVC
        return self
    }

    /// Convenience function for hiding the card and removing the card from the presenting view controller
    func dismissCard() {
        if sheetHeaderShadowEnabled, let scrollView = drivingScrollView() {
            scrollView.cancelForwardingDelegateInvocations(to: self)
        }
        hideCard(animated: true) {
            self.cardDragging?.removeDelegate(self.cardDraggingDelegateId)
            self.presentingVC?.removeCard(cardViewController: self)
            self.presentingVC = nil
        }
    }

    // MARK: - dragging delegate to automatically close on overlay tap or minimize

    func cardOverlayTapped() {
        if autoDismiss { dismissCard() }
        onClose?()
    }

    func cardWillChangePosition(_ position: CardPosition) {
        if position == .min {
            if autoDismiss { dismissCard() }
            onClose?()
        }
    }
}
