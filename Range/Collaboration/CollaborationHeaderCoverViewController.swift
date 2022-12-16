import RealmSwift
import UIKit

/// View that covers the collaboration header in full screen mode
/// Replicates the cover, so it contains the badge, name (non editable) and .../close buttons
class CollaborationHeaderCoverViewController: UIViewController {
    let collaboration: Collaboration
    private var collaborationNotificationToken: NotificationToken?
    private var geometryNotificationToken: NotificationToken?
    var onClose: (() -> Void)?

    private var badgeView: CollaborationBadgeView!
    private var nameLabel: UILabel!
    private var moreButton: UIButton!
    private var closeButton: UIButton!

    /// - Parameters:
    init(collaboration: Collaboration) {
        self.collaboration = collaboration
        super.init(nibName: nil, bundle: nil)
        collaborationNotificationToken = collaboration.observe { [weak self] _ in
            self?.onCollaborationUpdated()
        }
        geometryNotificationToken = collaboration.feature.first?.geometry.first?.observe { [weak self] _ in
            self?.onCollaborationUpdated()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        collaborationNotificationToken?.invalidate()
        geometryNotificationToken?.invalidate()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        updateShadow()

        view.backgroundColor = .dynamicColor(light: .Neutral_01, dark: .Neutral_10)

        let bottomStroke = UIView()
        bottomStroke.backgroundColor = .dynamicColor(
            light: .Neutral_01, // in light mode the same color as background as we don't want the stroke
            dark: .Neutral_07
        )
        view.addSubview(bottomStroke)
        bottomStroke.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(1)
        }

        badgeView = CollaborationBadgeView(collaboration)
        badgeView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(badgeTapped)))
        view.addSubview(badgeView)
        badgeView.snp.makeConstraints { make in
            make.leading.equalTo(16)
            make.top.equalTo(self.view.safeAreaLayoutGuide.snp.top).offset(9)
            make.bottom.equalToSuperview().offset(-9)
        }

        setupCloseButton()
        view.addSubview(closeButton)
        closeButton.snp.makeConstraints { make in
            make.width.height.equalTo(40)
            make.centerY.equalTo(badgeView.snp.centerY)
            make.trailing.equalToSuperview().inset(7)
        }

        setupMoreButton()
        view.addSubview(moreButton)
        moreButton.snp.makeConstraints { make in
            make.width.height.centerY.equalTo(closeButton)
            make.trailing.equalTo(closeButton.snp.leading)
        }

        setupNameLabel()
        view.addSubview(nameLabel)
        nameLabel.snp.makeConstraints { make in
            make.centerY.equalTo(badgeView.snp.centerY)
            make.leading.equalTo(badgeView.snp.trailing).offset(16)
            make.trailing.equalTo(moreButton.snp.leading).offset(-16)
        }

        onCollaborationUpdated()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateShadow()
        }
    }

    private func onCollaborationUpdated() {
        badgeView.isUserInteractionEnabled = !collaboration.isArchived
        let name = collaboration.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            nameLabel.textColor = .dynamicColor(light: .Neutral_06, dark: .Neutral_05)
            nameLabel.text = collaboration.status != nil
                ? "Add a task name..."
                : "Add a photo collection name..."
        } else {
            nameLabel.textColor = .dynamicColor(light: .Neutral_07, dark: .Neutral_04)
            nameLabel.text = collaboration.name.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func updateShadow() {
        let darkMode = traitCollection.userInterfaceStyle == .dark
        if darkMode {
            view.setShadowWithFigmaValues(x: 0, y: 6, blur: 10, opacity: 0.1)
        } else {
            view.setShadowWithFigmaValues(x: 0, y: 3, blur: 6, opacity: 0.1)
        }
    }

    @objc private func badgeTapped() {
        UIApplication.shared.sendAction(
            #selector(CollaborationFlowActions.editStatusAction), to: nil, from: self, for: nil
        )
    }

    @objc private func nameTapped() {
        UIApplication.shared.sendAction(
            #selector(CollaborationFlowActions.editNameAction), to: nil, from: self,
            for: FlowEvent(collaboration)
        )
    }
}

// MARK: Views

extension CollaborationHeaderCoverViewController {
    private func setupMoreButton() {
        let imageConfig = UIImage.SymbolConfiguration(textStyle: .callout)
            .applying(UIImage.SymbolConfiguration(weight: .regular))
        var config = UIButton.Configuration.plain()
        config.baseForegroundColor = .dynamicColor(light: .Neutral_07, dark: .Neutral_04)
        config.preferredSymbolConfigurationForImage = imageConfig
        moreButton = UIButton(
            configuration: config,
            primaryAction: UIAction(image: UIImage(systemName: "ellipsis")) { [weak self] _ in
                guard let self = self else { return }
                UIApplication.shared.sendAction(
                    #selector(CollaborationFlowActions.moreAction),
                    to: nil,
                    from: self,
                    for: FlowEvent(self.collaboration)
                )
            }
        )
    }

    private func setupCloseButton() {
        let imageConfig = UIImage.SymbolConfiguration(textStyle: .callout)
            .applying(UIImage.SymbolConfiguration(weight: .regular))
        var config = UIButton.Configuration.plain()
        config.baseForegroundColor = .dynamicColor(light: .Neutral_07, dark: .Neutral_04)
        config.preferredSymbolConfigurationForImage = imageConfig
        closeButton = UIButton(
            configuration: config,
            primaryAction: UIAction(image: UIImage(systemName: "xmark")) { [weak self] _ in
                self?.onClose?()
            }
        )
    }

    private func setupNameLabel() {
        let font = UIFont.preferredFont(forTextStyle: .body)
        let boldFont = UIFont(descriptor: font.fontDescriptor.withSymbolicTraits(.traitBold)!, size: 0)
        nameLabel = UILabel()
        nameLabel.textColor = .dynamicColor(light: .Neutral_07, dark: .Neutral_04)
        nameLabel.font = boldFont
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.isUserInteractionEnabled = true
        nameLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(nameTapped)))
    }
}
