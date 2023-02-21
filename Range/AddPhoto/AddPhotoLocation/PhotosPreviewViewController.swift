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
    unowned let imageCaches: ImageCaches
    unowned let confirmationVC: AddPhotoConfirmationViewController
    let uploads: Results<Upload>

    /// Token for observing changes in uploads
    private var notificationToken: NotificationToken?

    var imageAndText: UIStackView!
    var photoCountFont: UIFont {
        ._preferredFont(forTextStyle: .caption2, symbolicTraits: .traitBold)
    }

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
    ///    - imageCaches: for handling photos
    ///    - geometryId: display all uploads for collaborations for features for given geometry id
    ///    - confirmationVC: this view controller displays behing the `AddPhotoConfirmationViewController` and needs to know its height
    init(model: ProjectModel, imageCaches: ImageCaches, geometryId: String,
         confirmationVC: AddPhotoConfirmationViewController)
    {
        self.model = model
        self.imageCaches = imageCaches
        self.confirmationVC = confirmationVC
        // find all uploads for geometry id
        uploads = model.mainRealm.objects(Upload.self)
        // TODO: 827             .where { $0.fileType == .jpeg || $0.fileType == .png }
            .where { $0.placeholder == false &&
                $0.collaboration.feature.geometry.id.equals(geometryId)
            }
            .sorted(by: \Upload.timestamp, ascending: false)
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
        containerView.backgroundColor = .dynamicColor(light: .Neutral_02, dark: .Neutral_09)

        buildPhotoCountView()
        containerView.addSubview(imageAndText)
        imageAndText.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(8)
        }

        buildThumbnailsView()
        add(childController: thumbnailsVC, toView: containerView)

        thumbnailsVC.view.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(imageAndText.snp.bottom).offset(8)
            make.height.equalTo(ThumbnailsViewController.thumbnailHeight)
        }

        updateColors()
    }

    override func viewWillAppear(_: Bool) {
        notificationToken = uploads.observe { [weak self] (changes: RealmCollectionChange) in
            guard let self = self else { return }
            switch changes {
            case .initial:
                self.updatePhotoCount()
            case .update:
                self.updatePhotoCount()
            case let .error(error):
                Logger.model.error("observing uploads failed: \(error.localizedDescription, privacy: .public)")
            }
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

    private func buildPhotoCountView() {
        let imageConfig = UIImage.SymbolConfiguration(font: photoCountFont)
        let image = UIImage(systemName: "photo.on.rectangle.angled", withConfiguration: imageConfig)
        let imageView = UIImageView(image: image)
        imageView.tintColor = .dynamicColor(light: .Neutral_07, dark: .Neutral_04)

        photoCountLabel = UILabel()
        photoCountLabel.textColor = imageView.tintColor
        photoCountLabel.font = photoCountFont
        photoCountLabel.adjustsFontForContentSizeCategory = true
        updatePhotoCount()

        imageAndText = UIStackView(arrangedSubviews: [imageView, photoCountLabel])
        imageAndText.axis = .horizontal
        imageAndText.distribution = .equalSpacing
        imageAndText.spacing = 4
        imageAndText.alignment = .trailing
    }

    /// Update the label with photo count
    private func updatePhotoCount() {
        guard photoCountLabel != nil else { return }
        photoCountLabel.text = String(uploads.count) + " " +
            (uploads.count == 1 ? String(localized: "photo") : String(localized: "photos"))
    }

    private func buildThumbnailsView() {
        thumbnailsVC = ThumbnailsViewController(imageCaches: imageCaches, projectModel: model, uploads: uploads)
    }
}

extension PhotosPreviewViewController: CardPresentable {
    func height(forContainer containerView: UIView, cardPosition: CardPosition) -> CGFloat {
        if cardPosition == .medium {
            return -1 // not supported
        }

        view.layoutIfNeeded()
        let thumbnailsHeight: CGFloat = uploads.isEmpty
            ? 0
            : 8 + photoCountFont.lineHeight + 8 + ThumbnailsViewController.thumbnailHeight + 12
        return confirmationVC.height(forContainer: containerView, cardPosition: cardPosition)
            + thumbnailsHeight
    }
}
