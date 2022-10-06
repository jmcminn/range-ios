import Foundation
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
    let tagsView = TagsView()

    weak var imageCaches: ImageCaches?
    weak var projectModel: ProjectModel?
    weak var tableView: UITableView?

    /// listen to changes in upload and the content
    private var notificationToken: NotificationToken?

    unowned var upload: Upload? {
        didSet {
            updateContent()
            updateColors()
            if let upload = upload {
                // not observe again if already observing (also helps for the crash mentioned below)
                if let previousUpload = oldValue, previousUpload.id == upload.id {
                    return
                }
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.notificationToken = upload.observe { [weak self] change in
                        if case .deleted = change {
                            self?.upload = nil
                        } else {
                            DispatchQueue.main.async { [weak self] in
                                self?.updateContent()
                                guard let tableView = self?.tableView else { return }
                                tableView.beginUpdates()
                                tableView.endUpdates()
                            }
                        }
                    }
                }
            } else {
                notificationToken?.invalidate()
            }
        }
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .dynamicColor(light: .Neutral_02, dark: .Neutral_09)

        selectionStyle = .none

        setupViews()

        [avatarView, authorLabel, timestampLabel, imageAndDescriptionView, tagsView]
            .forEach(contentView.addSubview)

        [uploadImageView, descriptionBackground, descriptionSeparator, descriptionLabel]
            .forEach(imageAndDescriptionView.addSubview)

        avatarView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(CollaborationFeedViewController.distanceBetweenRows / 2)
            make.width.height.equalTo(32)
            make.leading.equalToSuperview().inset(16)
        }
        authorLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarView.snp.trailing).offset(8)
            make.bottom.equalTo(avatarView.snp.centerY)
        }
        timestampLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarView.snp.trailing).offset(8)
            make.top.equalTo(avatarView.snp.centerY)
        }
        imageAndDescriptionView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
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
        // tagsView will use the top and bottom 6 points of margin (for bigger tap area), so it's enough
        // to give 6 top offset and also make lower bottom margin
        tagsView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(imageAndDescriptionView.snp.bottom).offset(6)
            make.bottom.equalToSuperview().inset(CollaborationFeedViewController.distanceBetweenRows / 2 - 6)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        avatarView.layer.cornerRadius = 16
        avatarView.backgroundColor = .dynamicColor(light: .Neutral_04, dark: .Neutral_07)

        authorLabel.textColor = .dynamicColor(light: .Neutral_06, dark: .Neutral_04)
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
    }

    @objc private func tagsTapped() {
        guard let upload = upload else { return }
        // send action to the responder chain with custom UploadEvent
        UIApplication.shared.sendAction(
            #selector(CollaborationFlowActions.tagsSelected(sender:event:)),
            to: nil,
            from: self,
            for: UploadEvent(upload)
        )
    }

    override func traitCollectionDidChange(_: UITraitCollection?) {
        updateColors()
    }

    /// Update colors that doesn't automatically adapt to appearance change
    func updateColors() {
        imageAndDescriptionView.layer.borderColor = chooseColor(light: .Neutral_04, dark: .Neutral_07).cgColor
    }

    override func prepareForReuse() {
        upload = nil
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
            timestampLabel.text = TimeInterval.format1(upload.timestamp)
            let needsAspectRatioUpdateAfterImageLoad = possiblyUpdateUploadImageViewConstraints(upload: upload)
            guard let imageCaches = imageCaches else { return }
            uploadImageView.kf.setImage(
                with: imageCaches.imageProvider(forUpload: upload, thumbnailNumber: 1),
                placeholder: nil, options: nil, progressBlock: nil, completionHandler: { [weak self] _ in
                    guard needsAspectRatioUpdateAfterImageLoad else { return }
                    guard let self else { return }
                    // update the image aspect ratio
                    // once the image is loaded update the Upload.imageHeight2Width if it's not there
                    // yet, so the cell can have a proper height.
                    if let image = self.uploadImageView.image, let projectModel = self.projectModel,
                       image.size.width > 0
                    {
                        let imageHeight2Width = image.size.height / image.size.width
                        projectModel.mainRealm.writeAsync({
                            upload.imageHeightToWidth = imageHeight2Width
                        }, onComplete: { _ in
                            _ = self.possiblyUpdateUploadImageViewConstraints(upload: upload)
                            guard let tableView = self.tableView else { return }
                            tableView.beginUpdates()
                            tableView.endUpdates()
                        })
                    }
                }
            )
            tagsView.tags = upload.tags.where { $0.placeholder == false }
        } else {
            timestampLabel.text = nil
            uploadImageView.image = nil
            tagsView.tags = nil
        }
    }

    /// Updates the constraints for uploadImageView based on the Upload.imageHeight2Width (if present)
    /// Do it only if dynamicImageHeightInCollabFeed is enabled in DebugSettings
    /// - returns: `true` if this needs to be run again after image loaded...
    private func possiblyUpdateUploadImageViewConstraints(upload: Upload) -> Bool {
        // no dynamic height -> no need to update
        guard DebugSettings().dynamicImageHeightInCollabFeed else { return false }
        // no image height yet, need to update later
        guard let imageHeight2Width = upload.imageHeightToWidth else { return true }
        updateUploadImageViewConstraints(imageHeight2Width: imageHeight2Width)
        return false
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
