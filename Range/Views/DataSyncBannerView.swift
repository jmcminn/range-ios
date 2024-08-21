import Foundation
import UIKit

func _dataSyncInfoCard(_ state: UserDataSyncState.State) -> SheetCardViewController {
    let title = state == .offlinePending ? "Media Sync Pending" : "Media Sync In-progress"
    let description = state == .offlinePending
        ?
        "Your device currently has no Internet connection or uploading media via an internet connection has been disabled.\n\nYou can continue to use the app and when your device has an Internet connection or wifi access, all pending media will be synced to your Range Organization automatically when the app is open."
        :
        "Your device has established an Internet connection or wifi access and is currently syncing your pending media to your Organization. Once complete, this banner will disappear."
    return SheetCardViewController(icon: UIImage(systemName: "photo"), title: title, description: description)
}

class DataSyncBannerView: UIView {
    private let titleView = UIStackView()
    private let titleLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private var infoButton: UIButton!
    private var imageView: UIImageView!
    private var font: UIFont {
        ._preferredFont(forTextStyle: .callout, symbolicTraits: .traitBold)
    }

    var onTapped: (() -> Void)?

    init() {
        super.init(frame: .zero)

        titleView.axis = .horizontal
        titleView.distribution = .equalSpacing
        titleView.spacing = 8
        titleView.alignment = .trailing

        imageView = UIImageView(image: UIImage(
            systemName: "photo",
            withConfiguration: UIImage.SymbolConfiguration(font: font)
        ))
        imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        imageView.tintColor = .white
        titleLabel.textColor = .white
        titleLabel.font = font
        titleLabel.adjustsFontForContentSizeCategory = true
        activityIndicator.color = .white

        titleView.addArrangedSubview(imageView)
        titleView.addArrangedSubview(titleLabel)
        titleView.addArrangedSubview(activityIndicator)

        addSubview(titleView)
        titleView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-10)
            make.top.equalTo(self.safeAreaLayoutGuide.snp.top)
        }

        let imageConfig = UIImage
            .SymbolConfiguration(font: ._preferredFont(forTextStyle: .footnote, symbolicTraits: .traitBold))
        var config = UIButton.Configuration.plain()
        config.baseForegroundColor = .white
        config.preferredSymbolConfigurationForImage = imageConfig
        infoButton = RangeButton(
            configuration: config,
            primaryAction: UIAction(image: UIImage(systemName: "questionmark.circle"), handler: { [weak self] _ in
                self?.onTapped?()
            })
        )
        addSubview(infoButton)
        infoButton.snp.makeConstraints { make in
            make.width.height.equalTo(40)
            make.trailing.equalToSuperview().inset(8)
            make.centerY.equalTo(titleView.snp.centerY)
        }

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func tapped() {
        onTapped?()
    }

    func setState(_ state: UserDataSyncState.State) {
        switch state {
        case .offlinePending:
            backgroundColor = .Orange_Banner
            titleLabel.text = "Media Sync Pending"
            activityIndicator.isHidden = true
            activityIndicator.stopAnimating()
        case .onlineSync:
            backgroundColor = .Special_03
            titleLabel.text = "Media Sync In-progress"
            activityIndicator.isHidden = false
            activityIndicator.startAnimating()
        case .noPending:
            activityIndicator.isHidden = true
            activityIndicator.stopAnimating()
        }
    }
}
