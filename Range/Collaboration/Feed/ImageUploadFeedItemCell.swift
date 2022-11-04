import Foundation
import Kingfisher
import RealmSwift
import SnapKit
import UIKit

/// The table view cell to show image upload feed item
class ImageUploadFeedItemCell: UITableViewCell {
    let avatarView = UIView()
    let authorLabel = UILabel()
    let timestampLabel = UILabel()
    let imageAndDescriptionView = UIView()
    let uploadImageView = UIImageView()
    let descriptionLabel = LabelWithTextInsets()
    let descriptionBackground = UIView()
    let descriptionSeparator = UIView()
    let tagsView = TagsView(leftInset: FeedItemCells.leadingContentLayoutMargin -
        FeedItemCells.leadingVerticalLineMargin)
    let leftTagsViewGradient = GradientView()
    let rightTagsViewGradient = GradientView()

    var imageDataProvider: ImageDataProvider?
    weak var upload: Upload?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear

        selectionStyle = .none

        setupViews()

        [avatarView, authorLabel, timestampLabel, imageAndDescriptionView, tagsView]
            .forEach(contentView.addSubview)

        [uploadImageView, descriptionBackground, descriptionSeparator, descriptionLabel]
            .forEach(imageAndDescriptionView.addSubview)

        avatarView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.width.height.equalTo(32)
            make.leading.equalToSuperview().inset(16)
        }
        authorLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(FeedItemCells.leadingContentLayoutMargin)
            make.bottom.equalTo(avatarView.snp.centerY)
        }
        timestampLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(FeedItemCells.leadingContentLayoutMargin)
            make.top.equalTo(avatarView.snp.centerY)
        }
        imageAndDescriptionView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(FeedItemCells.leadingContentLayoutMargin)
            make.trailing.equalToSuperview().inset(16)
            make.top.equalTo(avatarView.snp.bottom).offset(14)
        }
        updateUploadImageViewConstraints(imageHeight2Width: 0.75)
        descriptionBackground.snp.makeConstraints { make in
            make.left.bottom.right.equalToSuperview()
            make.top.equalTo(uploadImageView.snp.bottom)
        }
        descriptionSeparator.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.top.equalTo(uploadImageView.snp.bottom)
            make.height.equalTo(1)
        }
        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(uploadImageView.snp.bottom)
            make.left.right.bottom.equalToSuperview()
        }
        tagsView.snp.makeConstraints { make in
            // +0.5 as this is the width of the vertical line, we don't want to colide with it
            make.leading.equalToSuperview().offset(FeedItemCells.leadingVerticalLineMargin + 0.5)
            make.trailing.equalToSuperview()
            make.top.equalTo(imageAndDescriptionView.snp.bottom).offset(12)
            make.bottom.equalToSuperview()
        }
        tagsView.addSubview(leftTagsViewGradient)
        tagsView.addSubview(rightTagsViewGradient)
        leftTagsViewGradient.snp.makeConstraints { make in
            make.width.equalTo(24)
            make.top.bottom.left.equalToSuperview()
        }
        rightTagsViewGradient.snp.makeConstraints { make in
            make.width.equalTo(24)
            make.top.bottom.right.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        avatarView.layer.cornerRadius = 16
        avatarView.backgroundColor = .dynamicColor(light: .Neutral_04, dark: .Neutral_07)

        authorLabel.textColor = .dynamicColor(light: .Neutral_07, dark: .Neutral_04)
        authorLabel.font = UIFont._preferredFont(forTextStyle: .callout, symbolicTraits: .traitBold)

        timestampLabel.textColor = .dynamicColor(light: .Neutral_06, dark: .Neutral_05)
        timestampLabel.font = .preferredFont(forTextStyle: .footnote)

        imageAndDescriptionView.backgroundColor = .dynamicColor(light: .Neutral_01, dark: .Neutral_10)
        imageAndDescriptionView.layer.borderWidth = 1
        imageAndDescriptionView.layer.cornerRadius = 16
        imageAndDescriptionView.clipsToBounds = true

        uploadImageView.contentMode = .scaleAspectFit
        uploadImageView.kf.indicatorType = .custom(indicator: ImageLoadingIndicator())

        descriptionLabel.textColor = .dynamicColor(light: .Neutral_06, dark: .Neutral_04)
        descriptionLabel.font = .preferredFont(forTextStyle: .subheadline)
        descriptionLabel.numberOfLines = 2
        descriptionLabel.lineBreakMode = .byTruncatingTail

        descriptionBackground.backgroundColor = .dynamicColor(light: .Neutral_03, dark: .Neutral_08)
        descriptionSeparator.backgroundColor = .dynamicColor(light: .Neutral_04, dark: .Neutral_07)

        tagsView.showAddTagCell = true
        tagsView.collectionView.backgroundColor = .dynamicColor(light: .Neutral_02, dark: .Neutral_09)
        tagsView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tagsTapped)))

        leftTagsViewGradient.backgroundColor = .clear
        // left to right gradient
        leftTagsViewGradient.gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        leftTagsViewGradient.gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)

        rightTagsViewGradient.backgroundColor = .clear
        // right to left gradient
        rightTagsViewGradient.gradientLayer.startPoint = CGPoint(x: 1, y: 0.5)
        rightTagsViewGradient.gradientLayer.endPoint = CGPoint(x: 0, y: 0.5)
    }

    @objc private func tagsTapped() {
        guard let upload = upload else { return }
        // send action to the responder chain with custom UploadEvent
        UIApplication.shared.sendAction(
            #selector(CollaborationFlowActions.tagsSelectedAction(sender:event:)),
            to: nil,
            from: self,
            for: FlowEvent(upload)
        )
    }

    override func traitCollectionDidChange(_: UITraitCollection?) {
        updateColors()
    }

    /// Update colors that doesn't automatically adapt to appearance change
    private func updateColors() {
        imageAndDescriptionView.layer.borderColor = chooseColor(light: .Neutral_04, dark: .Neutral_07).cgColor
        let gradientColor = chooseColor(light: .Neutral_02, dark: .Neutral_09)
        leftTagsViewGradient.gradientLayer.colors = [
            gradientColor.cgColor,
            gradientColor.withAlphaComponent(0).cgColor,
        ]
        rightTagsViewGradient.gradientLayer.colors = [
            gradientColor.cgColor,
            gradientColor.withAlphaComponent(0).cgColor,
        ]
    }

    override func prepareForReuse() {
        upload = nil
        updateContent()
    }

    func set(upload: Upload) {
        self.upload = upload
        updateContent()
        updateColors()
    }

    /// Called whenever an upload is set for the cell or updated
    /// Updates all the fields, loads the image and depending on the settings adjusts the uploadImageView constraints
    private func updateContent() {
        authorLabel.text = upload?.author?.displayName
        if let uploadDescription = upload?.uploadDescription, !uploadDescription.isEmpty {
            descriptionLabel.text = uploadDescription
            descriptionLabel.textInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        } else {
            descriptionLabel.text = nil
            // collapse the view if not description:
            descriptionLabel.textInsets = .zero
        }
        uploadImageView.kf.cancelDownloadTask()

        if let upload = upload {
            timestampLabel.text = Date.format1(upload.timestamp)
            possiblyUpdateUploadImageViewConstraints(upload: upload)
            guard let imageDataProvider = imageDataProvider else { return }
            uploadImageView.kf.setImage(with: imageDataProvider)
            tagsView.tags = upload.tags.where { $0.placeholder == false }
        } else {
            timestampLabel.text = nil
            uploadImageView.image = nil
            tagsView.tags = nil
        }
    }

    /// Updates the constraints for uploadImageView based on the Upload.imageHeight2Width (if present)
    /// Do it only if dynamicImageHeightInCollabFeed is enabled in DebugSettings
    private func possiblyUpdateUploadImageViewConstraints(upload: Upload) {
        // no dynamic height -> no need to update
        guard DebugSettings().dynamicImageHeightInCollabFeed else { return }
        // no image height yet
        guard let imageHeight2Width = upload.imageHeightToWidth else { return }
        updateUploadImageViewConstraints(imageHeight2Width: imageHeight2Width)
    }

    /// Updates the uploadImageView constraints to base height on the width and the image aspect ratio
    private func updateUploadImageViewConstraints(imageHeight2Width: Double) {
        uploadImageView.snp.remakeConstraints { make in
            make.top.left.right.equalToSuperview()
            make.height.equalTo(self.uploadImageView.snp.width).multipliedBy(imageHeight2Width)
                .priority(.high)
        }
    }
}
