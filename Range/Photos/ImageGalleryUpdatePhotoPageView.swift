import Foundation
import UIKit

class ImageGalleryUpdatePhotoPageView: UIView {
    var onUpdatePhotoAction: (() -> Void)?

    var pageInset: UIEdgeInsets = .zero { didSet {
        pageView.snp.remakeConstraints { make in
            make.top.equalToSuperview().inset(pageInset.top)
            make.leading.equalToSuperview().inset(pageInset.left)
            make.trailing.equalToSuperview().inset(pageInset.right)
            make.bottom.equalToSuperview().inset(pageInset.bottom)
        }
    }}
    private let pageView = UIView()
    private let contentView = UIView()

    init() {
        super.init(frame: .zero)
        backgroundColor = .clear

        setupViews()
        updateColors()
    }

    private func setupViews() {
        pageView.backgroundColor = .dynamic(.Neutral_09)
        pageView.layer.borderWidth = 1
        pageView.layer.cornerRadius = 13
        pageView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(updatePhotoAction)))

        addSubview(pageView)
        pageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        pageView.addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(40)
        }

        let updatePhotoButton = RoundShadowButton(
            image: UIImage(systemName: "camera.viewfinder") ?? UIImage(),
            imageTintColor: .white,
            variant: .secondary
        )
        updatePhotoButton.addTarget(self, action: #selector(updatePhotoAction), for: .touchUpInside)

        let updatePhotoLabel = UILabel()
        updatePhotoLabel.text = "Update Photo"
        updatePhotoLabel.font = ._preferredFont(forTextStyle: .callout, symbolicTraits: .traitBold)
        updatePhotoLabel.textColor = .dynamic(.Neutral_04)
        updatePhotoLabel.textAlignment = .center
        updatePhotoLabel.adjustsFontForContentSizeCategory = true

        let updatePhotoDescription = UILabel()
        updatePhotoDescription.text = "Add an updated version of this photo to show progress."
        updatePhotoDescription.font = .preferredFont(forTextStyle: .subheadline)
        updatePhotoDescription.textColor = .dynamic(.Neutral_05)
        updatePhotoDescription.textAlignment = .center
        updatePhotoDescription.numberOfLines = 0
        updatePhotoDescription.adjustsFontForContentSizeCategory = true

        [updatePhotoButton, updatePhotoLabel, updatePhotoDescription].forEach(contentView.addSubview)
        updatePhotoButton.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
        }
        updatePhotoLabel.snp.makeConstraints { make in
            make.top.equalTo(updatePhotoButton.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview()
        }
        updatePhotoDescription.snp.makeConstraints { make in
            make.top.equalTo(updatePhotoLabel.snp.bottom).offset(4)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// update colors
    override func traitCollectionDidChange(_: UITraitCollection?) {
        updateColors()
    }

    private func updateColors() {
        pageView.layer.borderColor = chooseColor(.Neutral_07).cgColor
    }

    @objc private func updatePhotoAction() {
        onUpdatePhotoAction?()
    }
}
