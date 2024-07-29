import Foundation
import OSLog
import Realm
import RealmSwift
import SnapKit
import UIKit

/// Shows the preview of photos when selecting a pin on the map for new photo
class PhotosPreviewViewController: UIViewController, NonModalCardCoordinating {
    var cardDragging: NonModalCardDragging?

    unowned let model: ProjectModel
    unowned let mediaCache: MediaCache
    unowned let confirmationVC: AddPhotoConfirmationViewController
    let collaborationName: String?
    let imageUploads: Results<Upload>
    let nonImageUploads: Results<Upload>
    /// Token for observing changes in uploads
    private var imageUploadsNotificationToken: NotificationToken?
    private var nonImageUploadsNotificationToken: NotificationToken?

    var imageAndText: UIStackView!
    var collaborationNameFont: UIFont {
        ._preferredFont(forTextStyle: .caption1, symbolicTraits: .traitBold)
    }

    var photoCountFont: UIFont {
        .preferredFont(forTextStyle: .caption1)
    }

    var collaborationNameLabel: UILabel?
    var photoCountLabel: UILabel!
    var thumbnailsVC: ThumbnailsViewController!
    var onClose: (() -> Void)?

    var roundedShadowView: RoundShadowView {
        view as! RoundShadowView
    }

    var containerView: UIView {
        roundedShadowView.containerView
    }

    /// - Parameters:
    ///    - model: for accessing project data
    ///    - mediaCache: for handling photos
    ///    - geometryId: display all uploads for collaborations for given geometry id
    ///    - confirmationVC: this view controller displays behing the `AddPhotoConfirmationViewController` and needs to know its height
    init(model: ProjectModel, mediaCache: MediaCache, geometryId: String,
         confirmationVC: AddPhotoConfirmationViewController)
    {
        self.model = model
        self.mediaCache = mediaCache
        self.confirmationVC = confirmationVC
        // find all uploads for geometry id
        imageUploads = model.mainRealm.objects(Upload.self)
            .where { $0.placeholder == false &&
                $0.collaboration.geometry.id.equals(geometryId)
            }
            .where { $0.fileType == .jpeg || $0.fileType == .png }
            .sorted(by: \Upload.createdAt, ascending: false)
        nonImageUploads = model.mainRealm.objects(Upload.self)
            .where { $0.placeholder == false &&
                $0.collaboration.geometry.id.equals(geometryId)
            }
            .where { $0.fileType != .jpeg && $0.fileType != .png }

        let collaboration = model.mainRealm.objects(Collaboration.self)
            .where { $0.placeholder == false &&
                $0.geometry.id.equals(geometryId)
            }.first
        var components: [String] = []
        if let collaboration {
            if let collaborationIdentifier = model.collaborationIdentifier(collaboration) {
                components.append(collaborationIdentifier)
            }
            if !collaboration.name.isEmpty {
                components.append(collaboration.name)
            }
        }
        if components.isEmpty {
            collaborationName = nil
        } else {
            collaborationName = components.joined(separator: " • ")
        }

        super.init(nibName: nil, bundle: nil)
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
        containerView.backgroundColor = .dynamic(.Neutral_09)

        setupCollaborationNameLabel()
        if let collaborationNameLabel {
            containerView.addSubview(collaborationNameLabel)
            collaborationNameLabel.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview().inset(8)
                make.top.equalToSuperview().offset(8)
            }
        }

        buildPhotoCountView()
        containerView.addSubview(imageAndText)
        imageAndText.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            if let collaborationNameLabel {
                make.top.equalTo(collaborationNameLabel.snp.bottom).offset(8)
            } else {
                make.top.equalToSuperview().offset(8)
            }
        }

        buildThumbnailsView()
        add(childController: thumbnailsVC, toView: containerView)

        thumbnailsVC.view.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(imageAndText.snp.bottom).offset(8)
            make.height.equalTo(ThumbnailsViewController.thumbnailHeight)
        }

        updatePhotoCount()
        updateColors()
    }

    override func viewWillAppear(_: Bool) {
        imageUploadsNotificationToken = imageUploads.observe { [weak self] (_: RealmCollectionChange) in
            guard let self = self else { return }
            self.updatePhotoCount()
        }
        nonImageUploadsNotificationToken = nonImageUploads.observe { [weak self] (_: RealmCollectionChange) in
            guard let self = self else { return }
            self.updatePhotoCount()
        }
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

    private func updateColors() {
        let darkMode = traitCollection.userInterfaceStyle == .dark
        if darkMode {
            view.setShadowWithFigmaValues(y: -6, blur: 10, opacity: 0.2)
        } else {
            view.setShadowWithFigmaValues(y: -3, blur: 6, opacity: 0.05)
        }
        roundedShadowView.topStrokeColor = darkMode ? .Neutral_07 : .Neutral_04
    }

    private func setupCollaborationNameLabel() {
        guard let collaborationName else { return }
        collaborationNameLabel = UILabel()
        collaborationNameLabel!.textColor = .dynamic(.Neutral_04)
        collaborationNameLabel!.font = collaborationNameFont
        collaborationNameLabel!.text = collaborationName
        collaborationNameLabel!.numberOfLines = 1
        collaborationNameLabel!.textAlignment = .center
        collaborationNameLabel!.lineBreakMode = .byTruncatingTail
    }

    private func buildPhotoCountView() {
        let imageConfig = UIImage.SymbolConfiguration(font: photoCountFont)
        let image = UIImage(systemName: "photo.on.rectangle.angled", withConfiguration: imageConfig)
        let imageView = UIImageView(image: image)
        imageView.tintColor = .dynamic(.Neutral_05)

        photoCountLabel = UILabel()
        photoCountLabel.textColor = imageView.tintColor
        photoCountLabel.font = photoCountFont
        photoCountLabel.adjustsFontForContentSizeCategory = true

        imageAndText = UIStackView(arrangedSubviews: [imageView, photoCountLabel])
        imageAndText.axis = .horizontal
        imageAndText.distribution = .equalSpacing
        imageAndText.spacing = 4
        imageAndText.alignment = .trailing
    }

    /// Update the label with photo count
    private func updatePhotoCount() {
        guard photoCountLabel != nil else { return }
        var components: [String] = []

        // show at least the photos count if there's no docs (so show "0 Photos")
        if imageUploads.count > 0 || nonImageUploads.count == 0 {
            components.append(String(imageUploads.count) + " " +
                (imageUploads.count == 1 ? String(localized: "Photo") : String(localized: "Photos")))
        }
        if nonImageUploads.count > 0 {
            components.append(String(nonImageUploads.count) + " " +
                (nonImageUploads.count == 1 ? String(localized: "Document") : String(localized: "Documents")))
        }
        photoCountLabel.text = components.joined(separator: " • ")

        if imageUploads.count > 0 {
            // show thumbnails, do not show count
            imageAndText.isHidden = true
            thumbnailsVC.view.isHidden = false
            thumbnailsVC.view.snp.remakeConstraints { make in
                make.leading.trailing.equalToSuperview()
                if let collaborationNameLabel {
                    make.top.equalTo(collaborationNameLabel.snp.bottom).offset(8)
                } else {
                    make.top.equalToSuperview().offset(12)
                }
                make.height.equalTo(ThumbnailsViewController.thumbnailHeight)
            }
        } else {
            // no thumbnails, show the count
            imageAndText.isHidden = false
            thumbnailsVC.view.isHidden = true
            imageAndText.snp.remakeConstraints { make in
                make.centerX.equalToSuperview()
                if let collaborationNameLabel {
                    make.top.equalTo(collaborationNameLabel.snp.bottom).offset(8)
                } else {
                    make.top.equalToSuperview().offset(8)
                }
            }
        }
    }

    private func buildThumbnailsView() {
        thumbnailsVC = ThumbnailsViewController(mediaCache: mediaCache, projectModel: model, uploads: imageUploads)
    }
}

extension PhotosPreviewViewController: CardPresentable {
    func height(forContainer containerView: UIView, cardPosition: CardPosition) -> CGFloat {
        if cardPosition == .medium {
            return -1 // not supported
        }

        view.layoutIfNeeded()
        var thumbnailsHeight = 0.0
        if collaborationName != nil {
            thumbnailsHeight += 8 + collaborationNameFont.lineHeight
        }
        if !imageUploads.isEmpty {
            // thumbnails visible
            thumbnailsHeight += collaborationName == nil ? 12 : 8
            thumbnailsHeight += ThumbnailsViewController.thumbnailHeight + 12
        } else {
            // image/docs count visible
            thumbnailsHeight += 8 + photoCountFont.lineHeight + 8
        }
        return confirmationVC.height(forContainer: containerView, cardPosition: cardPosition)
            + thumbnailsHeight
    }
}
