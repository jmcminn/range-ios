import Foundation
import RealmSwift
import SnapKit
import UIKit

/// This class represent the whole content view of the Fullscreen media view
class FullscreenMediaDetailsViewController: UIViewController {
    private let projectModel: ProjectModel
    private let mediaCache: MediaCache
    private let showCollaborationButton: Bool
    /// For images the upload can have correlated uploads. We want to display them all and mark as versions (1, 2, ...)
    /// This array also contains the upload
    private(set) var correlatedUploads: Results<Upload>
    private var uploadsNotificationToken: NotificationToken?
    private let initialUploadIndex: Int

    /// when the there's a new upload selected (or no upload)
    var onCurrentUploadSwitched: (() -> Void)?

    var onHeightChanged: (() -> Void)?

    /// Contains Collaboration button (optional, if not displaying from collaboration window) and images gallery
    private var headerView = UIView()
    /// Details of the upload selected in the gallery view
    private var contentView = UIView()
    /// shown when "update photo" card is shown in the gallery
    private var contentPlaceholderView = UIView()

    /// for creating the layout and calculating height
    private var lastView: UIView!

    private(set) var collaborationButton: CollaborationButton?
    private(set) var galleryVC: ImageGalleryViewController<MediaKey>?
    private var galleryCurrentPageObservation: NSKeyValueObservation?
    private var previewBox: UIView?
    private var fileNameLabel: UILabel?
    private(set) var previewVC: UploadPreviewViewController?

    private let authorView = UIView()
    private let avatarView = AvatarView()
    private let authorLabel = UILabel()
    private let timestampLabel = UILabel()

    private(set) var descriptionHeader: UIView!
    private let descriptionOrAddView = UIView()
    private let descriptionLabel = LabelWithTextInsets()
    private(set) var addDescriptionButton: UIView! // visible when there's no description

    private(set) var tagsHeader: UIView!
    private let tagsOrAddView = UIView()
    private let tagsView = TagsView()
    private(set) var addTagsButton: UIView! // visible when there's no description

    private var commentsVC: FeedViewController!
    // shown when there's no comments in the feed
    private let noCommentsView = UIView()

    var onPhotoSelected: ((Upload) -> Void)?
    var onUpdatePhotoAction: (() -> Void)?
    var onAnnotationsSelected: ((Upload) -> Void)?

    var galleryMediaKeys: [MediaKey] {
        correlatedUploads.compactMap {
            .autoAnnotatedMediaKey(projectId: projectModel.projectId, upload: $0, thumbnailNumber: 1)
        }
    }

    /// Currently presented Upload (for images we may present multiple `correlatedUploads` for given `upload`
    var currentUpload: Upload? {
        if let galleryVC {
            let uploadIndex = galleryVC.currentPage
            guard uploadIndex < correlatedUploads.count else { return nil }
            return correlatedUploads[uploadIndex]
        } else {
            return correlatedUploads.first
        }
    }

    var lastReportedCurrentUpload: Upload?

    /// Initializer
    init(
        projectModel: ProjectModel,
        mediaCache: MediaCache,
        correlatedUploads: Results<Upload>,
        initialUploadIndex: Int,
        showCollaborationButton: Bool
    ) {
        self.projectModel = projectModel
        self.mediaCache = mediaCache
        self.correlatedUploads = correlatedUploads
        self.initialUploadIndex = initialUploadIndex
        self.showCollaborationButton = showCollaborationButton
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        galleryCurrentPageObservation?.invalidate()
        uploadsNotificationToken?.invalidate()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .dynamic(.Neutral_09)
        view.translatesAutoresizingMaskIntoConstraints = false

        setupViews()
        setupContentPlaceholderView()
        updateColors()

        galleryCurrentPageObservation = galleryVC?.observe(\.currentPage) { [weak self] _, _ in
            self?.galleryPageSwitchedHandler()
        }
        observeUploads()
        galleryPageSwitchedHandler()

        onHeightChanged?()
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
        // -----------------------------------------------------------------------------------------
        // ---- Header -----------------------------------------------------------------------------
        headerView.backgroundColor = .dynamic(.Neutral_10)
        view.addSubview(headerView)
        headerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }

        // ---- Collaboration ----------------------------------------------------------------------
        // only add if there's a collaboration and it has a canvas (it should always have a canvas but
        // in case of placeholders or bad data just don't show the button)
        if showCollaborationButton, let collaboration = currentUpload?.collaboration.first,
           collaboration.feature.first?.geometry.first?.canvas.first != nil
        {
            setupCollaborationButton(collaboration: collaboration)
            headerView.addSubview(collaborationButton!)
            collaborationButton!.snp.makeConstraints { make in
                make.top.equalToSuperview()
                make.leading.trailing.equalToSuperview().inset(16)
            }
        }
        // ---- Media ------------------------------------------------------------------------------
        if let currentUpload, currentUpload.isImage {
            addGalleryVC()
        } else {
            addPreviewView()
        }

        // -----------------------------------------------------------------------------------------
        // ---- Content ----------------------------------------------------------------------------
        contentView.backgroundColor = .dynamic(.Neutral_09)
        view.addSubview(contentView)

        _addSpacer(1, .dynamic(.Neutral_07))
        // ---- Author  ----------------------------------------------------------------------------
        setupAuthorView()
        _addSubview(authorView)
        // ---- Description  -----------------------------------------------------------------------
        _addSpacer(1, .dynamic(.Neutral_07), inset: true)
        _addSpacer(12)
        descriptionHeader = createSectionHeaderView(iconName: "text.quote", title: String(localized: "Description"))
        descriptionHeader
            .addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(descriptionTapped)))
        _addSubview(descriptionHeader)
        _addSpacer(12)
        addDescriptionOrAddView()
        _addSpacer(16)

        // ---- Tags  ------------------------------------------------------------------------------
        _addSpacer(1, .dynamic(.Neutral_07), inset: true)
        _addSpacer(12)
        tagsHeader = createSectionHeaderView(iconName: "tag", title: String(localized: "Tags"))
        tagsHeader.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tagsTapped)))
        _addSubview(tagsHeader)
        _addSpacer(12)
        addTagsOrAddView()
        _addSpacer(16)

        // ---- Comments  --------------------------------------------------------------------------
        _addSpacer(1, .dynamic(.Neutral_07), inset: true)
        _addSpacer(12)
        let commentsHeader = createSectionHeaderView(iconName: "bubble.right", title: String(localized: "Comments"))
        // hide edit button for comments
        commentsHeader.subviews.filter { $0.tag == 66 }.forEach { $0.isHidden = true }
        _addSubview(commentsHeader)
        _addSpacer(4)

        contentView.snp.makeConstraints { make in
            make.top.equalTo(headerView.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(lastView)
        }
    }

    private func setupContentPlaceholderView() {
        contentPlaceholderView.backgroundColor = .dynamic(.Neutral_09)
        // separator line
        let lineView = UIView()
        lineView.backgroundColor = .dynamic(.Neutral_07)
        contentPlaceholderView.addSubview(lineView)
        lineView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(1)
        }
        // display 3 placeholder boxes
        let boxHeights: [Double] = [40, 64, 64]
        let boxViews = boxHeights.map { _ in
            let boxView = UIView()
            boxView.backgroundColor = .dynamic(.Neutral_08)
            boxView.layer.cornerRadius = 16
            return boxView
        }
        for (index, boxView) in boxViews.enumerated() {
            contentPlaceholderView.addSubview(boxView)
            boxView.snp.makeConstraints { make in
                if index == 0 {
                    make.top.equalToSuperview().offset(16)
                } else {
                    make.top.equalTo(boxViews[index - 1].snp.bottom).offset(16)
                }
                make.leading.trailing.equalToSuperview().inset(16)
                make.height.equalTo(boxHeights[index])
                if index == boxViews.count - 1 {
                    make.bottom.equalToSuperview().inset(16)
                }
            }
        }
        view.addSubview(contentPlaceholderView)
        contentPlaceholderView.snp.makeConstraints { make in
            make.top.equalTo(headerView.snp.bottom)
            make.leading.trailing.equalToSuperview()
        }
    }

    /// Return the height of the view
    func height() -> CGFloat {
        view.layoutIfNeeded()
        if currentUpload != nil {
            return headerView.frame.height + lastView.frame.maxY
        } else {
            return contentPlaceholderView.frame.maxY
        }
    }

    /// Adds subview, sets its constraints and sets it as the `lastView`
    private func _addSubview(_ subview: UIView, inset: Bool = false) {
        contentView.addSubview(subview)
        subview.snp.makeConstraints { [lastView] make in
            make.leading.trailing.equalToSuperview().inset(inset ? 16 : 0)
            if let lastView {
                make.top.equalTo(lastView.snp.bottom)
            } else {
                make.top.equalToSuperview()
            }
        }
        lastView = subview
    }

    /// Adds a spacer below `lastView` and sets it as the lastView
    private func _addSpacer(_ height: CGFloat, _ backgroundColor: UIColor = .dynamic(.Neutral_09),
                            inset: Bool = false)
    {
        let spacer = UIView()
        spacer.backgroundColor = backgroundColor
        contentView.addSubview(spacer)
        spacer.snp.makeConstraints { make in
            if let lastView {
                make.top.equalTo(lastView.snp.bottom)
            } else {
                make.top.equalToSuperview()
            }
            make.height.equalTo(height)
            make.leading.trailing.equalToSuperview().inset(inset ? 16 : 0)
        }
        lastView = spacer
    }

    private func setupCollaborationButton(collaboration: Collaboration) {
        collaborationButton = CollaborationButton(model: projectModel, collaboration: collaboration)
        collaborationButton!.addTarget(self, action: #selector(collaborationTapped), for: .touchUpInside)
    }

    private func addGalleryVC() {
        let galleryHeightToWidth = correlatedUploads.compactMap(\.imageHeightToWidth).max() ?? 4.0 / 3.0
        let galleryVC = ImageGalleryViewController(
            imageDataProviderFactory: { [mediaCache] in
                mediaCache.imageProvider(forKey: $0)
            },
            photoKeys: galleryMediaKeys,
            pageHeight2Width: galleryHeightToWidth
        )
        galleryVC.onPhotoSelected = { [weak self] in
            guard let self, let galleryVC = self.galleryVC else { return }
            self.onPhotoSelected?(correlatedUploads[galleryVC.currentPage])
        }
        galleryVC.onAnnotationsSelected = { [weak self] in
            guard let self, let galleryVC = self.galleryVC else { return }
            onAnnotationsSelected?(correlatedUploads[galleryVC.currentPage])
        }
        galleryVC.onMoreAction = { [weak self] sourceView in
            self?.moreAction(sourceView: sourceView)
        }
        galleryVC.onUpdatePhotoAction = { [weak self] in self?.onUpdatePhotoAction?() }
        galleryVC.setCurrentPage(initialUploadIndex)
        galleryVC.showVersions = correlatedUploads.count > 1
        add(childController: galleryVC, toView: headerView)
        // When showing multiple photos the horizontal margin is bigger to show partially other photos
        // The same is true for 1 photo only, because then we show the "update photo" page as a 2nd one
        let horizontalMargin = 44.0
        galleryVC.view.snp.makeConstraints { make in
            if let collaborationButton {
                make.top.equalTo(collaborationButton.snp.bottom).offset(16)
            } else {
                make.top.equalToSuperview()
            }
            make.leading.trailing.equalToSuperview()
            // make the photo take the whole available width
            make.height.equalTo(view.snp.width)
                .offset(-2 * horizontalMargin * galleryHeightToWidth)
                .multipliedBy(galleryHeightToWidth)
            make.bottom.equalToSuperview().inset(16)
        }
        self.galleryVC = galleryVC
    }

    private func addPreviewView() {
        let previewBox = UIView()
        previewBox.layer.cornerRadius = 13
        previewBox.layer.borderWidth = 1
        previewBox.backgroundColor = .dynamic(.Neutral_10)
        previewBox.clipsToBounds = true
        self.previewBox = previewBox

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
        previewVC.upload = currentUpload
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

        let moreButton = RoundShadowButton(
            image: UIImage(systemName: "ellipsis") ?? UIImage(),
            size: 32,
            imageTintColor: .white,
            variant: .darkBlurred,
            withBorder: false
        ).withTapAreaInsets(UIEdgeInsets(top: -8, left: -8, bottom: -8, right: -8))
        previewBox.addSubview(moreButton)
        moreButton.snp.makeConstraints { make in
            make.top.trailing.equalToSuperview().inset(8)
        }

        let previewTappedRecognizer = UITapGestureRecognizer(target: self, action: #selector(previewTapped))
        /// disable recognizing when more button is tapped
        previewTappedRecognizer.delegate = self
        previewBox.addGestureRecognizer(previewTappedRecognizer)
        moreButton.addTarget(self, action: #selector(moreAction), for: .touchUpInside)

        headerView.addSubview(previewBox)
        previewBox.snp.makeConstraints { make in
            if let collaborationButton {
                make.top.equalTo(collaborationButton.snp.bottom).offset(16)
            } else {
                make.top.equalToSuperview()
            }
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().inset(16)
        }
    }

    @objc private func previewTapped() {
        guard let currentUpload else { return }
        onPhotoSelected?(currentUpload)
    }

    @objc private func collaborationTapped() {
        guard let collaboration = currentUpload?.collaboration.first else { return }
        UIApplication.shared.sendAction(
            #selector(ProjectFlowActions.showCollaborationAction),
            to: nil,
            from: self,
            for: FlowEvent(collaboration)
        )
    }

    private func setupAuthorView() {
        authorLabel.textColor = .dynamic(.Neutral_04)
        authorLabel.font = ._preferredFont(forTextStyle: .callout, symbolicTraits: .traitBold)
        authorLabel.adjustsFontForContentSizeCategory = true
        authorLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        timestampLabel.textColor = .dynamic(.Neutral_05)
        timestampLabel.font = .preferredFont(forTextStyle: .footnote)
        timestampLabel.adjustsFontForContentSizeCategory = true
        timestampLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        [avatarView, authorLabel, timestampLabel].forEach(authorView.addSubview)
        avatarView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.width.height.equalTo(32)
            make.leading.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().offset(-16).priority(.high)
        }
        authorLabel.snp.makeConstraints { make in
            make.top.greaterThanOrEqualToSuperview().offset(16)
            make.leading.equalTo(avatarView.snp.trailing).offset(8)
            make.trailing.equalToSuperview().inset(16)
            make.bottom.equalTo(avatarView.snp.centerY).priority(.high)
        }
        timestampLabel.snp.makeConstraints { make in
            make.top.equalTo(authorLabel.snp.bottom)
            make.leading.trailing.equalTo(authorLabel)
            make.bottom.lessThanOrEqualToSuperview().offset(-16)
        }
    }

    /// this view shows either the description label or "add description" button depending on the state
    private func addDescriptionOrAddView() {
        setupDescriptionLabel()
        descriptionLabel
            .addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(descriptionTapped)))
        addDescriptionButton = createAddButton(title: String(localized: "Add description"), handler: { [weak self] _ in
            self?.descriptionTapped()
        })
        _addSubview(descriptionOrAddView)
    }

    private func setupDescriptionLabel() {
        descriptionLabel.font = .preferredFont(forTextStyle: .subheadline)
        descriptionLabel.textColor = .dynamic(.Neutral_04)
        descriptionLabel.adjustsFontForContentSizeCategory = true
        descriptionLabel.textInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        descriptionLabel.numberOfLines = 0
        descriptionLabel.isUserInteractionEnabled = true
    }

    private func addTagsOrAddView() {
        setupTagsView()
        tagsView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tagsTapped)))
        addTagsButton = createAddButton(title: String(localized: "Add Tags"), handler: { [weak self] _ in
            self?.tagsTapped()
        })
        _addSubview(tagsOrAddView)
    }

    private func setupTagsView() {
        tagsView.backgroundColor = .dynamic(.Neutral_09)
        tagsView.collectionView.backgroundColor = .dynamic(.Neutral_09)
    }

    /// Creates a button but returns a wrapping UIView to add horizontal padding
    private func createAddButton(title: String, handler: @escaping UIActionHandler) -> UIView {
        var config = UIButton.Configuration.blackButton()
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
        config.baseBackgroundColor = .dynamic(.Neutral_10)
        return RangeButton(
            configuration: config,
            primaryAction: UIAction(title: title, handler: handler)
        ).withCustomRangeHighlightColor()
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
        editLabel.backgroundColor = .dynamic(.Neutral_10)
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
        guard let currentUpload else { return }
        UIApplication.shared.sendAction(
            #selector(ProjectFlowActions.editDescriptionAction), to: nil, from: self,
            for: FlowEvent(currentUpload)
        )
    }

    @objc private func tagsTapped() {
        guard let currentUpload else { return }
        UIApplication.shared.sendAction(
            #selector(ProjectFlowActions.editTagsAction), to: nil, from: self,
            for: FlowEvent(currentUpload)
        )
    }

    @objc private func moreAction(sourceView: UIView) {
        let upload = if let galleryVC { correlatedUploads[galleryVC.currentPage] } else { correlatedUploads[0] }
        UIApplication.shared.sendAction(
            #selector(ProjectFlowController.moreAction), to: nil, from: self,
            for: FlowEvent(upload, sourceView: sourceView)
        )
    }
}

// MARK: - uploads observation / updating UI

extension FullscreenMediaDetailsViewController {
    /// Observe all uploads and authors.
    /// If upload is deleted, remove from gallery
    /// If upload is updated, update the UI
    /// If upload is added, insert into gallery and make the current one
    /// If author is updated, update the UI
    private func observeUploads() {
        uploadsNotificationToken = correlatedUploads.observe { [weak self] change in
            guard let self = self else { return }
            switch change {
            case .initial:
                // nothing to do
                break
            case let .update(_, deletions: deletions, insertions: insertions, modifications: modifications):
                for deletionIndex in deletions {
                    self.galleryVC?.photoRemoved(atIndex: deletionIndex)
                }
                for insertionIndex in insertions {
                    self.galleryVC?.addPhoto(galleryMediaKeys[insertionIndex], atIndex: insertionIndex)
                }
                for modificationIndex in modifications {
                    self.galleryVC?.updatePhotoKey(galleryMediaKeys[modificationIndex], atIndex: modificationIndex)
                }
                if !modifications.isEmpty {
                    self.uploadUpdatedHandler()
                }
                if !insertions.isEmpty {
                    // scroll to last one if anything inserted
                    self.galleryVC?.setCurrentPage(correlatedUploads.count - 1)
                }
            case .error: break
            }
        }
    }

    /// Called when the current upload was switched.
    private func galleryPageSwitchedHandler() {
        guard lastReportedCurrentUpload != currentUpload else { return }

        lastReportedCurrentUpload = currentUpload
        uploadUpdatedHandler()

        // switch between upload and placeholder view
        contentView.isHidden = currentUpload == nil
        contentPlaceholderView.isHidden = currentUpload != nil

        onCurrentUploadSwitched?()
        onHeightChanged?()
    }

    /// Called when the current upload's data was updated
    private func uploadUpdatedHandler() {
        guard let currentUpload else { return }
        avatarView.setAvatar(forParticipant: currentUpload.author)
        authorLabel.attributedText = NSAttributedString(
            string: currentUpload.author?.displayName ?? "",
            attributes: [.strikethroughStyle: currentUpload.author?.strikethroughStyle ?? 0]
        )
        timestampLabel.text = Date.format1(currentUpload.timestamp)

        updateDescription()
        updateTags()
        fileNameLabel?.text = currentUpload.fileName

        if let galleryVC {
            galleryVC.updatePhotoKey(galleryMediaKeys[galleryVC.currentPage], atIndex: galleryVC.currentPage)
        }
        onHeightChanged?()
    }

    private func updateDescription() {
        guard let currentUpload else { return }
        let hasDescription = !(currentUpload.uploadDescription ?? "").isEmpty

        descriptionHeader.subviews.filter { $0.tag == 66 }.forEach { $0.isHidden = !hasDescription }
        descriptionLabel.text = currentUpload.uploadDescription
        descriptionOrAddView.subviews.forEach { $0.removeFromSuperview() }
        if hasDescription {
            descriptionOrAddView.addSubview(descriptionLabel)
            descriptionLabel.snp.remakeConstraints { make in
                make.edges.equalToSuperview()
            }
        } else {
            descriptionOrAddView.addSubview(addDescriptionButton)
            addDescriptionButton.snp.remakeConstraints { make in
                make.top.bottom.equalToSuperview()
                make.leading.trailing.equalToSuperview().inset(16)
            }
        }
    }

    private func updateTags() {
        guard let currentUpload else { return }
        let hasTags = !currentUpload.tags.isEmpty

        tagsView.tags = currentUpload.tags.where { $0.placeholder == false }
        tagsHeader.subviews.filter { $0.tag == 66 }.forEach { $0.isHidden = !hasTags }
        tagsOrAddView.subviews.forEach { $0.removeFromSuperview() }
        if hasTags {
            tagsOrAddView.addSubview(tagsView)
            tagsView.snp.remakeConstraints { make in
                make.edges.equalToSuperview()
            }
        } else {
            tagsOrAddView.addSubview(addTagsButton)
            addTagsButton.snp.remakeConstraints { make in
                make.top.bottom.equalToSuperview()
                make.leading.trailing.equalToSuperview().inset(16)
            }
        }
    }
}

extension FullscreenMediaDetailsViewController: UIGestureRecognizerDelegate {
    /// Registering tap gesture recognizer on the preview view will steal 'touchUpInside' events from UIControls so we need to make sure
    /// that the view ignores touchs on UIControls
    func gestureRecognizer(_: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touch.view is UIControl {
            return false
        }
        return true
    }
}
