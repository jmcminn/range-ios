import Foundation
import RealmSwift
import SnapKit
import UIKit

/// This class represent the whole content view of the Fullscreen media view
class FullscreenMediaDetailsViewController: UIViewController {
    private let projectModel: ProjectModel
    private let mediaCache: MediaCache
    private let showCollaborationButton: Bool
    private let upload: Upload
    /// For images the upload can have correlated uploads. We want to display them all and mark as versions (1, 2, ...)
    /// This array also contains the upload
    private(set) var correlatedUploads: [Upload]
    var onCorrelatedUploadsUpdated: (() -> Void)?

    /// when the there's a new upload selected (or no upload)
    var onCurrentUploadSwitched: (() -> Void)?

    private var notificationTokens: [NotificationToken] = []

    var onHeightChanged: (() -> Void)?
    /// for creating the layout and calculating height
    private var lastView: UIView!

    private(set) var collaborationButton: CollaborationButton?
    private(set) var galleryVC: ImageGalleryViewController<MediaKey>?
    private var galleryCurrentPageObservation: NSKeyValueObservation?
    private var previewBox: UIView?
    private var fileNameLabel: UILabel?
    private(set) var previewVC: UploadPreviewViewController?

    private let authorView = UIView()
    private let avatarView = UIView()
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
            return upload
        }
    }

    var lastReportedCurrentUpload: Upload?

    /// Initializer
    init(projectModel: ProjectModel, mediaCache: MediaCache, upload: Upload, showCollaborationButton: Bool) {
        self.projectModel = projectModel
        self.mediaCache = mediaCache
        self.showCollaborationButton = showCollaborationButton
        self.upload = upload
        correlatedUploads = Array(projectModel.correlatedUploads(upload))
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        galleryCurrentPageObservation?.invalidate()
        notificationTokens.forEach { $0.invalidate() }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .dynamic(.Neutral_09)
        view.translatesAutoresizingMaskIntoConstraints = false

        setupViews()
        updateColors()

        galleryCurrentPageObservation = galleryVC?.observe(\.currentPage) { [weak self] _, _ in
            self?.onUploadUpdated()
        }
        observeUploads()
        onUploadUpdated()

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
        // ---- Collaboration ----------------------------------------------------------------------
        // only add if there's a collaboration and it has a canvas (it should always have a canvas but
        // in case of placeholders or bad data just don't show the button)
        if showCollaborationButton, let collaboration = upload.collaboration.first,
           collaboration.feature.first?.geometry.first?.canvas.first != nil
        {
            addCollaborationButton(collaboration: collaboration)
            _addSpacer(16, .dynamic(.Neutral_10))
        }

        // ---- Media ------------------------------------------------------------------------------
        if upload.isImage {
            addGalleryVC()
        } else {
            addPreviewView()
        }
        _addSpacer(16, .dynamic(.Neutral_10))

        _addSpacer(1, .dynamic(.Neutral_07))

        // ---- Author  ----------------------------------------------------------------------------
        setupAuthorView()
        _addSubview(authorView)

        // ---- Description  -----------------------------------------------------------------------
        _addSpacer(1, .dynamic(.Neutral_07), inset: true)
        _addSpacer(12, .dynamic(.Neutral_09))
        descriptionHeader = createSectionHeaderView(iconName: "text.quote", title: String(localized: "Description"))
        descriptionHeader
            .addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(descriptionTapped)))
        _addSubview(descriptionHeader)
        _addSpacer(12, .dynamic(.Neutral_09))
        addDescriptionOrAddView()
        _addSpacer(16, .dynamic(.Neutral_09))

        // ---- Tags  ------------------------------------------------------------------------------
        _addSpacer(1, .dynamic(.Neutral_07), inset: true)
        _addSpacer(12, .dynamic(.Neutral_09))
        tagsHeader = createSectionHeaderView(iconName: "tag", title: String(localized: "Tags"))
        tagsHeader.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tagsTapped)))
        _addSubview(tagsHeader)
        _addSpacer(12, .dynamic(.Neutral_09))
        addTagsOrAddView()
        _addSpacer(16, .dynamic(.Neutral_09))

        // ---- Comments  --------------------------------------------------------------------------
        _addSpacer(1, .dynamic(.Neutral_07), inset: true)
        _addSpacer(12, .dynamic(.Neutral_09))
        let commentsHeader = createSectionHeaderView(iconName: "bubble.right", title: String(localized: "Comments"))
        // hide edit button for comments
        commentsHeader.subviews.filter { $0.tag == 66 }.forEach { $0.isHidden = true }
        _addSubview(commentsHeader)
        _addSpacer(4, .dynamic(.Neutral_09))
    }

    /// Return the height of the view
    func height() -> CGFloat {
        view.layoutIfNeeded()
        return lastView.frame.maxY
    }

    /// Adds subview, sets its constraints and sets it as the `lastView`
    private func _addSubview(_ subview: UIView, inset: Bool = false) {
        view.addSubview(subview)
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
    private func _addSpacer(_ height: CGFloat, _ backgroundColor: UIColor, inset: Bool = false) {
        let spacer = UIView()
        spacer.backgroundColor = backgroundColor
        view.addSubview(spacer)
        spacer.snp.makeConstraints { make in
            make.top.equalTo(lastView.snp.bottom)
            make.height.equalTo(height)
            make.leading.trailing.equalToSuperview().inset(inset ? 16 : 0)
        }
        lastView = spacer
    }

    private func addCollaborationButton(collaboration: Collaboration) {
        collaborationButton = CollaborationButton(model: projectModel, collaboration: collaboration)
        collaborationButton!.addTarget(self, action: #selector(collaborationTapped), for: .touchUpInside)

        // put collaboration button in a wrapper view to have a different background color on the sides
        let collaborationButtonWrapper = UIView()
        collaborationButtonWrapper.backgroundColor = .dynamic(.Neutral_10)
        collaborationButtonWrapper.addSubview(collaborationButton!)
        collaborationButton!.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(16)
        }
        _addSubview(collaborationButtonWrapper)
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
        galleryVC.onMoreAction = { [weak self] in
            guard let self, let galleryVC = self.galleryVC else { return }
            let upload = correlatedUploads[galleryVC.currentPage]
            UIApplication.shared.sendAction(
                #selector(ProjectFlowController.moreAction), to: nil, from: self,
                for: FlowEvent(upload, sourceView: galleryVC.viewForCurrentPage)
            )
        }
        galleryVC.setCurrentPage(correlatedUploads.firstIndex(of: upload) ?? 0)
        galleryVC.showVersions = correlatedUploads.count > 1
        add(childController: galleryVC, toView: view)
        // When showing multiple photos the horizontal margin is bigger to show partially other photos
        // If one photo only is shown make it take the whole width
        let horizontalMargin = correlatedUploads.count > 1 ? 44.0 : 16.0
        galleryVC.view.snp.makeConstraints { make in
            if let lastView {
                make.top.equalTo(lastView.snp.bottom)
            } else {
                make.top.equalToSuperview()
            }
            make.leading.trailing.equalToSuperview()
            // make the photo take the whole available width
            make.height.equalTo(view.snp.width)
                .offset(-2 * horizontalMargin * galleryHeightToWidth)
                .multipliedBy(galleryHeightToWidth)
        }
        lastView = galleryVC.view
        self.galleryVC = galleryVC
    }

    private func addPreviewView() {
        let previewBox = UIView()
        previewBox.layer.cornerRadius = 13
        previewBox.layer.borderWidth = 1
        previewBox.backgroundColor = .dynamic(.Neutral_10)
        previewBox.clipsToBounds = true
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

        // put the view in a wrapper view to have a different background color on the sides
        let wrapperView = UIView()
        wrapperView.backgroundColor = .dynamic(.Neutral_10)
        wrapperView.addSubview(previewBox)
        previewBox.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(16)
        }
        _addSubview(wrapperView)
    }

    @objc private func previewTapped() {
        onPhotoSelected?(upload)
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

    private func setupAuthorView() {
        avatarView.layer.cornerRadius = 16
        avatarView.backgroundColor = .dynamic(.Neutral_07)

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
}

// MARK: - uploads observation / updating UI

extension FullscreenMediaDetailsViewController {
    /// Observe all uploads and authors.
    /// If upload is deleted, remove from correlatedUploads
    /// If upload is updated, update the UI
    /// If author is updated, update the UI
    private func observeUploads() {
        notificationTokens.forEach { $0.invalidate() }
        notificationTokens.removeAll()

        for (index, upload) in correlatedUploads.enumerated() {
            let uploadNotificationToken = upload.observe { [weak self] change in
                guard let self else { return }
                if case .deleted = change {
                    self.correlatedUploads.remove(at: index)
                    if correlatedUploads.isEmpty {
                        // this is the last upload, the card will close
                    } else {
                        self.galleryVC?.photoRemoved(atIndex: index)
                    }
                    /// reattach the observers as indexes are now different
                    self.observeUploads()
                    self.onCorrelatedUploadsUpdated?()
                } else {
                    self.onUploadUpdated()
                }
            }
            notificationTokens.append(uploadNotificationToken)

            if let author = upload.author {
                let authorNotificationToken = author.observe { [weak self] _ in
                    self?.onUploadUpdated()
                }
                notificationTokens.append(authorNotificationToken)
            }
        }
    }

    private func onUploadUpdated() {
        guard let currentUpload else { return }

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

        if lastReportedCurrentUpload != currentUpload {
            lastReportedCurrentUpload = currentUpload
            onCurrentUploadSwitched?()
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
