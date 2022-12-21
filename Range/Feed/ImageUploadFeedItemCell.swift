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
    var moreButton: UIButton!
    let imageAndDescriptionView = UIView()
    let uploadImageView = UIImageView()
    let descriptionLabel = LabelWithTextInsets()
    let descriptionBackground = UIView()
    let descriptionSeparator = UIView()
    let commentsLabel = LabelWithTextInsets()
    let tagsView = TagsView(leftInset: FeedItemCells.leadingContentLayoutMargin -
        FeedItemCells.leadingVerticalLineMargin)
    let leftTagsViewGradient = GradientView()
    let rightTagsViewGradient = GradientView()

    /// Set when setting the Upload
    private var uploadId: String?
    /// Required to fetch the upload for actions triggering
    private weak var model: ProjectModel?
    var imageDataProvider: ImageDataProvider?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear

        selectionStyle = .none

        setupViews()

        [avatarView, authorLabel, timestampLabel, moreButton, imageAndDescriptionView, tagsView]
            .forEach(contentView.addSubview)

        [uploadImageView, descriptionBackground, descriptionSeparator, descriptionLabel, commentsLabel]
            .forEach(imageAndDescriptionView.addSubview)

        avatarView.snp.makeConstraints { make in
            make.top.equalToSuperview().priority(.high)
            make.width.height.equalTo(32)
            make.leading.equalToSuperview().inset(16)
        }
        authorLabel.snp.makeConstraints { make in
            make.top.lessThanOrEqualToSuperview() // for bigger font when author label is the top most view
            make.leading.equalToSuperview().offset(FeedItemCells.leadingContentLayoutMargin)
            make.trailing.equalToSuperview().offset(-56) // place for more button
            make.bottom.equalTo(avatarView.snp.centerY)
        }
        timestampLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(FeedItemCells.leadingContentLayoutMargin)
            make.trailing.equalToSuperview().offset(-56) // place for more button
            make.top.equalTo(avatarView.snp.centerY)
        }
        moreButton.snp.makeConstraints { make in
            make.width.height.equalTo(40)
            make.centerY.equalTo(avatarView)
            make.trailing.equalToSuperview().inset(16)
        }
        imageAndDescriptionView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(FeedItemCells.leadingContentLayoutMargin)
            make.trailing.equalToSuperview().inset(16)
            make.top.greaterThanOrEqualTo(avatarView.snp.bottom).offset(14)
            make.top.greaterThanOrEqualTo(timestampLabel.snp.bottom).offset(14)
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
            make.left.right.equalToSuperview()
        }
        commentsLabel.snp.makeConstraints { make in
            make.top.equalTo(descriptionLabel.snp.bottom)
            make.leading.trailing.equalToSuperview().inset(10)
            make.bottom.equalToSuperview()
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

        moreButton = FeedItemCells.createMoreButton(handler: { [weak self] _ in
            self?.moreAction()
        })

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

        commentsLabel.font = ._preferredFont(forTextStyle: .subheadline, symbolicTraits: .traitBold)
        commentsLabel.textColor = .Primary_Blue_04
        commentsLabel.isUserInteractionEnabled = true
        commentsLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(commentsTapped)))

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
        updateContent(upload: nil)
    }

    /// Updates all the fields
    /// Don't store the Upload as the object might be invalidated while the cell is displayed.
    /// Store the upload id and model so the upload can be fetched if needed.
    func set(upload: Upload, model: ProjectModel) {
        uploadId = upload.id
        self.model = model
        updateContent(upload: upload)
        updateColors()
    }

    /// Called whenever an upload is set for the cell or updated
    /// Updates all the fields, loads the image and depending on the settings adjusts the uploadImageView constraints
    private func updateContent(upload: Upload?) {
        authorLabel.text = upload?.author?.displayName

        uploadImageView.kf.cancelDownloadTask()

        if let upload = upload {
            timestampLabel.text = Date.format1(upload.timestamp)
            possiblyUpdateUploadImageViewConstraints(upload: upload)
            guard let imageDataProvider = imageDataProvider else { return }
            uploadImageView.kf.setImage(with: imageDataProvider)
            tagsView.tags = upload.tags.where { $0.placeholder == false }

            let showDescription = !(upload.uploadDescription?.isEmpty ?? true)
            let commentsCount = upload.comments.count
            let showComments = commentsCount > 0
            if let uploadDescription = upload.uploadDescription, !uploadDescription.isEmpty {
                descriptionLabel.text = uploadDescription
                descriptionLabel.textInsets = UIEdgeInsets(
                    top: 10,
                    left: 10,
                    bottom: showComments ? 6 : 10,
                    right: 10
                )
            } else {
                descriptionLabel.text = nil
                // collapse the view if not description:
                descriptionLabel.textInsets = .zero
            }
            if showComments {
                commentsLabel.text = commentsCount == 1
                    ? String(localized: "1 comment")
                    : String(localized: "\(commentsCount) comments")
                commentsLabel.textInsets = UIEdgeInsets(top: showDescription ? 0 : 10, left: 0, bottom: 10, right: 0)
            } else {
                commentsLabel.text = nil
                // collapse the view if no comments
                commentsLabel.textInsets = .zero
            }
        } else {
            timestampLabel.text = nil
            uploadImageView.image = nil
            descriptionLabel.text = nil
            commentsLabel.text = nil
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

    @objc private func commentsTapped() {
        guard let model = model,
              let uploadId = uploadId,
              let upload = model.mainRealm.object(ofType: Upload.self, forPrimaryKey: uploadId) else { return }
        UIApplication.shared.sendAction(
            #selector(ProjectFlowActions.showFullscreenMediaCommentsAction),
            to: nil,
            from: self,
            for: FlowEvent(upload)
        )
    }

    @objc private func tagsTapped() {
        guard let model = model,
              let uploadId = uploadId,
              let upload = model.mainRealm.object(ofType: Upload.self, forPrimaryKey: uploadId) else { return }
        // send action to the responder chain with custom UploadEvent
        UIApplication.shared.sendAction(
            #selector(ProjectFlowActions.editTagsAction), to: nil, from: self,
            for: FlowEvent(upload)
        )
    }

    private func moreAction() {
        guard let model = model,
              let uploadId = uploadId,
              let upload = model.mainRealm.object(ofType: Upload.self, forPrimaryKey: uploadId) else { return }
        UIApplication.shared.sendAction(
            #selector(ProjectFlowController.moreAction), to: nil, from: self,
            for: FlowEvent(upload)
        )
    }
}
