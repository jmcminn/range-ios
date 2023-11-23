import Foundation
import RealmSwift
import UIKit

class FullscreenMediaSummaryViewController: UIViewController {
    let scrollView = UIScrollView()

    private let projectModel: ProjectModel
    private let mediaCache: MediaCache
    private let showCollaborationButton: Bool
    private let upload: Upload
    private var uploadNotificationToken: NotificationToken?

    private let stackView = UIStackView()
    private(set) var galleryVC: ImageGalleryViewController<MediaKey>?
    private var previewWrapperView: UIView?
    private var previewBox: UIView?
    private var fileNameLabel: UILabel?
    private(set) var previewVC: UploadPreviewViewController?
    private(set) var collaborationButton: CollaborationButton!
    private(set) var descriptionHeader: UIView!
    private let descriptionLabel = LabelWithTextInsets()
    private(set) var addDescriptionButton: UIView! // visible when there's no description
    private(set) var tagsHeader: UIView!
    private let tagsView = TagsView()
    private(set) var addTagsButton: UIView! // visible when there's no description

    var onPhotoSelected: (() -> Void)?
    var onAnnotationsSelected: (() -> Void)?

    var galleryMediaKey: MediaKey? { .autoAnnotatedMediaKey(
        projectId: projectModel.projectId,
        upload: upload,
        thumbnailNumber: 1
    ) }

    /// Initializer
    init(projectModel: ProjectModel, mediaCache: MediaCache, upload: Upload, showCollaborationButton: Bool) {
        self.projectModel = projectModel
        self.mediaCache = mediaCache
        self.showCollaborationButton = showCollaborationButton
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

        view.backgroundColor = .dynamic(.Neutral_10)

        setupViews()
        updateColors()

        onUploadUpdated()

        uploadNotificationToken = upload.observe { [weak self] change in
            if case .deleted = change {
            } else {
                self?.onUploadUpdated()
            }
        }
    }

    private func onUploadUpdated() {
        let hasDescription = !(upload.uploadDescription ?? "").isEmpty
        let hasTags = !upload.tags.isEmpty

        fileNameLabel?.text = upload.fileName
        descriptionLabel.text = upload.uploadDescription
        tagsView.tags = upload.tags.where { $0.placeholder == false }

        descriptionHeader.subviews.filter { $0.tag == 66 }.forEach { $0.isHidden = !hasDescription }
        descriptionLabel.isHidden = !hasDescription
        addDescriptionButton.isHidden = hasDescription
        tagsHeader.subviews.filter { $0.tag == 66 }.forEach { $0.isHidden = !hasTags }
        tagsView.isHidden = !hasTags
        addTagsButton.isHidden = hasTags

        if let galleryVC = galleryVC {
            galleryVC.updatePhotoKey(galleryMediaKey, atIndex: 0)
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateColors()
        }
    }

    private func updateColors() {
        previewBox?.layer.borderColor = chooseColor(.Neutral_07).cgColor
    }

    private func setupViews() {
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        stackView.axis = .vertical
        stackView.spacing = 8

        scrollView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        let mediaView: UIView
        if upload.isImage {
            setupGalleryVC()
            mediaView = galleryVC!.view
        } else {
            setupPreviewView()
            mediaView = previewWrapperView!
        }
        stackView.addArrangedSubview(mediaView)

        // only add if there's a collaboration and it has a canvas (it should always have a canvas but
        // in case of placeholders or bad data just don't show the button)
        if showCollaborationButton, let collaboration = upload.collaboration.first,
           collaboration.feature.first?.geometry.first?.canvas.first != nil
        {
            stackView.setCustomSpacing(12, after: mediaView)
            setupCollaborationButton(collaboration: collaboration)
            // put collaboration button in a wrapper view to have horizontal margin
            let collaborationButtonWrapper = UIView()
            collaborationButtonWrapper.addSubview(collaborationButton)
            collaborationButton.snp.makeConstraints { make in
                make.top.bottom.equalToSuperview()
                make.leading.trailing.equalToSuperview().inset(16)
            }
            stackView.addArrangedSubview(collaborationButtonWrapper)
            stackView.setCustomSpacing(12, after: collaborationButtonWrapper)
        } else {
            stackView.setCustomSpacing(20, after: mediaView)
        }

        descriptionHeader = createSectionHeaderView(iconName: "text.quote", title: String(localized: "Description"))
        descriptionHeader
            .addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(descriptionTapped)))
        stackView.addArrangedSubview(descriptionHeader)

        setupDescriptionLabel()
        descriptionLabel
            .addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(descriptionTapped)))
        stackView.addArrangedSubview(descriptionLabel)
        stackView.setCustomSpacing(16, after: descriptionLabel)
        addDescriptionButton = createAddButton(title: String(localized: "Add description"), handler: { [weak self] _ in
            self?.descriptionTapped()
        })
        stackView.addArrangedSubview(addDescriptionButton)
        stackView.setCustomSpacing(16, after: addDescriptionButton)

        tagsHeader = createSectionHeaderView(iconName: "tag", title: String(localized: "Tags"))
        tagsHeader.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tagsTapped)))
        stackView.addArrangedSubview(tagsHeader)

        tagsView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tagsTapped)))
        stackView.addArrangedSubview(tagsView)

        addTagsButton = createAddButton(title: String(localized: "Add Tags"), handler: { [weak self] _ in
            self?.tagsTapped()
        })
        stackView.addArrangedSubview(addTagsButton)
    }

    private func setupGalleryVC() {
        let galleryHeightToWidth = upload.imageHeightToWidth ?? 4.0 / 3.0
        let galleryVC = ImageGalleryViewController(
            imageDataProviderFactory: { [mediaCache] in
                mediaCache.imageProvider(forKey: $0)
            },
            photoKeys: [galleryMediaKey],
            pageHeight2Width: galleryHeightToWidth
        )
        galleryVC.onPhotoSelected = { [weak self] in
            self?.onPhotoSelected?()
        }
        galleryVC.onAnnotationsSelected = { [weak self] in
            self?.onAnnotationsSelected?()
        }
        add(childController: galleryVC, toView: stackView)
        galleryVC.view.snp.makeConstraints { make in
            make.width.equalTo(scrollView)
            // make the photo take the whole available width
            make.height.equalTo(scrollView.snp.width).offset(-32.0 * galleryHeightToWidth)
                .multipliedBy(galleryHeightToWidth)
        }
        self.galleryVC = galleryVC
    }

    private func setupPreviewView() {
        let previewWrapperView = UIView()
        previewWrapperView.backgroundColor = .dynamic(.Neutral_10)
        stackView.addSubview(previewWrapperView)
        previewWrapperView.snp.makeConstraints { make in
            make.width.equalTo(scrollView)
//            make.height.equalTo(276)
        }
        self.previewWrapperView = previewWrapperView

        let previewBox = UIView()
        previewBox.layer.cornerRadius = 13
        previewBox.layer.borderWidth = 1
        previewBox.backgroundColor = .dynamic(.Neutral_09)
        previewBox.clipsToBounds = true
        previewWrapperView.addSubview(previewBox)
        previewBox.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(16)
        }
        self.previewBox = previewBox
        previewBox.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(previewTapped)))

        let previewVC = UploadPreviewViewController(
            projectModel: projectModel,
            mediaCache: mediaCache
        )
        // safe to cache web kit generated thumbnails, this view is always fully visible when generating thumbnail
        previewVC.cacheWebKitGeneratedThumbnails = true
        add(childController: previewVC, toView: previewBox)
        let initialAspectRatio = 0.68 // as in the design
        previewVC.view.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(previewVC.view.snp.width).multipliedBy(initialAspectRatio)
            make.bottom.equalToSuperview().offset(-42)
        }
        previewVC.onAspectRatioLoaded = { heightToWidth in
            previewVC.view.snp.remakeConstraints { make in
                make.top.leading.trailing.equalToSuperview()
                make.height.equalTo(previewVC.view.snp.width).multipliedBy(heightToWidth)
                make.bottom.equalToSuperview().offset(-42)
            }
        }
        previewVC.upload = upload
        self.previewVC = previewVC

        let separator = UIView()
        separator.backgroundColor = .dynamic(.Neutral_07)
        previewBox.addSubview(separator)
        separator.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(1)
            make.bottom.equalToSuperview().offset(-41)
        }

        let fileNameLabel = UILabel()
        fileNameLabel.textColor = .dynamic(.Neutral_04)
        fileNameLabel.adjustsFontForContentSizeCategory = true
        fileNameLabel.lineBreakMode = .byTruncatingTail
        fileNameLabel.font = ._preferredFont(forTextStyle: .callout, symbolicTraits: .traitBold)
        previewBox.addSubview(fileNameLabel)
        fileNameLabel.snp.makeConstraints { make in
            make.top.equalTo(separator.snp.bottom)
            make.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(10)
        }
        self.fileNameLabel = fileNameLabel
    }

    @objc private func previewTapped() {
        onPhotoSelected?()
    }

    private func setupCollaborationButton(collaboration: Collaboration) {
        collaborationButton = CollaborationButton(collaboration: collaboration)
        collaborationButton.addTarget(self, action: #selector(collaborationTapped), for: .touchUpInside)
    }

    @objc private func collaborationTapped() {
        guard let collaboration = upload.collaboration.first else { return }
        UIApplication.shared.sendAction(
            #selector(ProjectFlowActions.showCollaborationAction),
            to: nil,
            from: self,
            for: FlowEvent(collaboration)
        )
    }

    private func setupDescriptionLabel() {
        descriptionLabel.font = .preferredFont(forTextStyle: .subheadline)
        descriptionLabel.textColor = .dynamic(.Neutral_04)
        descriptionLabel.adjustsFontForContentSizeCategory = true
        descriptionLabel.textInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        descriptionLabel.numberOfLines = 0
        descriptionLabel.isUserInteractionEnabled = true
    }

    /// Creates a button but returns a wrapping UIView to add horizontal padding
    private func createAddButton(title: String, handler: @escaping UIActionHandler) -> UIView {
        var config = UIButton.Configuration.blackButton()
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
        let button = RangeButton(
            configuration: UIButton.Configuration.blackButton(),
            primaryAction: UIAction(title: title, handler: handler)
        ).withCustomRangeHighlightColor()
        let wrapperView = UIView()
        wrapperView.addSubview(button)
        button.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(16)
        }
        return wrapperView
//        expandButton.setContentHuggingPriority(.required, for: .horizontal)
    }

    /// Creates a view with an icon, title and edit button
    private func createSectionHeaderView(iconName: String, title: String) -> UIView {
        let sectionHeader = UIView()

        let font = UIFont._preferredFont(forTextStyle: .subheadline, symbolicTraits: .traitBold)
        let iconView =
            UIImageView(image: UIImage(systemName: iconName,
                                       withConfiguration: UIImage.SymbolConfiguration(font: font)))
        iconView.tintColor = .dynamic(.Neutral_05)
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        iconView.setContentCompressionResistancePriority(.required, for: .horizontal)

        let label = UILabel()
        label.font = font
        label.textColor = iconView.tintColor
        label.adjustsFontForContentSizeCategory = true
        label.text = title

        let editLabel = LabelWithTextInsets()
        editLabel.textInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        editLabel.borderColor = .dynamic(.Neutral_07)
        editLabel.autoround = true
        editLabel.font = .preferredFont(forTextStyle: .subheadline)
        editLabel.textColor = .dynamic(.Neutral_04)
        editLabel.adjustsFontForContentSizeCategory = true
        editLabel.text = String(localized: "Edit")
        editLabel.backgroundColor = .dynamic(.Neutral_09)
        editLabel.setContentHuggingPriority(.required, for: .horizontal)
        editLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        editLabel.tag = 66 // mark it so it can be later hidden

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

    @objc private func descriptionTapped() {
        UIApplication.shared.sendAction(
            #selector(ProjectFlowActions.editDescriptionAction), to: nil, from: self,
            for: FlowEvent(upload)
        )
    }

    @objc private func tagsTapped() {
        UIApplication.shared.sendAction(
            #selector(ProjectFlowActions.editTagsAction), to: nil, from: self,
            for: FlowEvent(upload)
        )
    }
}
