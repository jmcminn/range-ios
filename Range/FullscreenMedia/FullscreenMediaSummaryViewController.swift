import Foundation
import RealmSwift
import UIKit

class FullscreenMediaSummaryViewController: UIViewController {
    let scrollView = UIScrollView()

    private let projectModel: ProjectModel
    private let imageCaches: ImageCaches
    private let upload: Upload
    private var uploadNotificationToken: NotificationToken?

    private let stackView = UIStackView()
    private(set) var galleryVC: ImageGalleryViewController<String>!
    private let descriptionLabel = LabelWithTextInsets()
    private let tagsView = TagsView()

    /// Initializer
    init(projectModel: ProjectModel, imageCaches: ImageCaches, upload: Upload) {
        self.projectModel = projectModel
        self.imageCaches = imageCaches
        self.upload = upload
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        uploadNotificationToken?.invalidate()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .dynamicColor(light: .Neutral_01, dark: .Neutral_10)

        setupViews()

        onUploadUpdated()

        uploadNotificationToken = upload.observe { [weak self] change in
            if case .deleted = change {
            } else {
                self?.onUploadUpdated()
            }
        }
    }

    private func onUploadUpdated() {
        descriptionLabel.text = upload.uploadDescription
        tagsView.tags = upload.tags.where { $0.placeholder == false }
    }

    private func setupViews() {
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        stackView.axis = .vertical
        stackView.spacing = 16

        scrollView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        setupGalleryVC()
        stackView.addArrangedSubview(galleryVC.view)

        let descriptionHeader = createSectionHeaderView(iconName: "text.quote", title: String(localized: "Description"))
        stackView.addArrangedSubview(descriptionHeader)
        stackView.setCustomSpacing(8, after: descriptionHeader)

        setupDescriptionLabel()
        stackView.addArrangedSubview(descriptionLabel)

        let tagsHeader = createSectionHeaderView(iconName: "tag", title: String(localized: "Tags"))
        stackView.addArrangedSubview(tagsHeader)
        stackView.setCustomSpacing(8, after: tagsHeader)

        setupTagsView()
        stackView.addArrangedSubview(tagsView)
    }

    private func setupGalleryVC() {
        let uploadCacheKey = uploadKey(projectId: projectModel.projectId, uploadId: upload.id, thumbnailNumber: 1)
        let galleryHeightToWidth = upload.imageHeightToWidth ?? 4.0 / 3.0
        galleryVC = ImageGalleryViewController(
            imageDataProviderFactory: { [imageCaches] in
                imageCaches.imageProvider(forPhotoWithCacheKey: $0)
            },
            photoKeys: [uploadCacheKey],
            pageHeight2Width: galleryHeightToWidth
        )
        add(childController: galleryVC, toView: stackView)
        galleryVC.view.snp.makeConstraints { make in
            make.width.equalTo(scrollView)
            // make the photo take the whole available width
            make.height.equalTo(scrollView.snp.width).offset(-32).multipliedBy(galleryHeightToWidth)
        }
    }

    private func setupDescriptionLabel() {
        descriptionLabel.font = .preferredFont(forTextStyle: .subheadline)
        descriptionLabel.textColor = .dynamicColor(light: .Neutral_07, dark: .Neutral_04)
        descriptionLabel.adjustsFontForContentSizeCategory = true
        descriptionLabel.textInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        descriptionLabel.numberOfLines = 0
    }

    private func setupTagsView() {
//        tagsView.collectionView.backgroundColor = .dynamicColor(light: .Neutral_02, dark: .Neutral_09)
    }

    /// Creates a view with an icon, title and edit button
    private func createSectionHeaderView(iconName: String, title: String) -> UIView {
        let sectionHeader = UIView()

        let font = UIFont._preferredFont(forTextStyle: .subheadline, symbolicTraits: .traitBold)
        let iconView =
            UIImageView(image: UIImage(systemName: iconName,
                                       withConfiguration: UIImage.SymbolConfiguration(font: font)))
        iconView.tintColor = .dynamicColor(light: .Neutral_06, dark: .Neutral_05)
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        iconView.setContentCompressionResistancePriority(.required, for: .horizontal)

        let label = UILabel()
        label.font = font
        label.textColor = iconView.tintColor
        label.adjustsFontForContentSizeCategory = true
        label.text = title

        let editLabel = LabelWithTextInsets()
        editLabel.textInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        editLabel.borderColor = .dynamicColor(light: .Neutral_04, dark: .Neutral_07)
        editLabel.font = .preferredFont(forTextStyle: .subheadline)
        editLabel.textColor = .dynamicColor(light: .Neutral_07, dark: .Neutral_04)
        editLabel.adjustsFontForContentSizeCategory = true
        editLabel.text = String(localized: "Edit")
        editLabel.backgroundColor = .dynamicColor(light: .Neutral_02, dark: .Neutral_09)
        editLabel.setContentHuggingPriority(.required, for: .horizontal)
        editLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        [iconView, label, editLabel].forEach(sectionHeader.addSubview)
        iconView.snp.makeConstraints { make in
            make.top.greaterThanOrEqualToSuperview()
            make.leading.equalToSuperview().inset(16)
            make.bottom.lessThanOrEqualToSuperview()
            make.centerY.equalToSuperview()
        }
        label.snp.makeConstraints { make in
            make.top.greaterThanOrEqualToSuperview()
            make.leading.equalTo(iconView.snp.trailing).offset(8)
            make.trailing.equalTo(editLabel.snp.leading).offset(-8)
            make.bottom.lessThanOrEqualToSuperview()
            make.centerY.equalToSuperview()
        }
        editLabel.snp.makeConstraints { make in
            make.top.greaterThanOrEqualToSuperview()
            make.trailing.equalToSuperview().inset(16)
            make.bottom.lessThanOrEqualToSuperview()
            make.centerY.equalToSuperview()
        }

        return sectionHeader
    }
}
