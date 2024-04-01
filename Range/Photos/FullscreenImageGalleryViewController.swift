import Combine
import Foundation
import Kingfisher
import SwiftUI
import UIKit

// To use SwiftUI AnnotationsToolbarView over a gallery (UIScrollView) we need to wrap the gallery
// into a SwiftUI view and use SwiftUI to compose the views. Otherwise the AnnotationsToolbarView
// cannot extend over the photos (when showing some selectors like scribble thickness). If it's allowed
// to extend over the photos, then it steals the gestures from UIScrollView below and I couldn't find
// a way to make it work.
//
// View hierarchy (indentation = subviews hierarchy, views on the same level ordered from front to back)
// - FullscreenImageGalleryViewController.view (UIView)
//    - top buttons (UIViews for now)
//    - FullscreenImageGalleryView (SwiftUI view)
//      - AnnotationsToolbarView
//      - FullscreenImageGalleryScrollViewRepresentable (wraps gallery UIScrollView for SwiftUI)
//
// See the Miro board for the diagram of view/view models: https://miro.com/app/board/o9J_lTkhi7M=/?moveToWidget=3458764558296723520&cot=14

// implementation loosely based on https://github.com/zvonicek/ImageSlideshow

/// Image gallery presenting the photos as a horizontal scroll with only 1 image visible at a time and taking the full width.
/// It allows for removing photos.
/// It supports zooming in on the photos.
/// It uses `pageSeparator` overlayed on top of the page views to create a moving border between photos that is giving the impression
/// that the pages are changing width (see the iPhone Photos app for how it works). In fact the pages are layed out next to each other
/// but the separator, that has the same color as the view background, create distance between them (and make the photos look narrower.
/// just like in the Photos app)
class FullscreenImageGalleryViewController<PhotoKey: Equatable>: UIViewController, UIScrollViewDelegate {
    let imageDataProviderFactory: (PhotoKey) -> RangeImageDataProvider
    private var photoKeys: [PhotoKey?]

    var onCancel: (() -> Void)?
    /// Passes removedPhotosIndices (see it's description for how to handle them, empty if photo removal not enabled)
    /// and updated annotations for each photo (for not removed photos only)
    var onDone: (([Int], [Annotations?]) -> Void)?
    /// Whether to show the remove photos button
    let removePhotosEnabled: Bool

    /// The indices of removed photos (the indices are added as user is removing the photos.
    /// ACHTUNG: The index at position N+1 is the index in the array of photos with removals 0..N already applied)
    var removedPhotosIndices: [Int] = []

    /// views representing pages for images
    private var pages: [FullscreenImageGalleryPageView]
    /// a black stripe overlayed on top of pages that adds a separation between 2 visible pages
    private let pageSeparator = UIView()
    let scrollView = UIScrollView()
    private let currentPageLabel = UILabel()
    private var annotationsSettingsButton: UIButton!
    private var deleteButton: UIButton!
    private var cancelButton: UIButton!
    private var confirmButton: UIButton!

    /// Annotations view model - one for all pages (there's one annotations toolbar for all pages)
    private let annotationsEditorViewModel: AnnotationsEditorViewModel
    /// for storing the annotationsViewModel scribbling subscriber
    private var annotationsViewModelScribbleModeSubscriber: AnyCancellable?
    /// array of Annotations object for each page
    private var annotationsEditorPerPage: [AnnotationsEditor]
    private let annotationsSettings = AnnotationsDevSettings()

    /// Transitioning delegate to manage the transition to this controller
    var fullscreenTransitioningDelegate: FullscreenImageGalleryTransitioningDelegate<PhotoKey>?

    var currentPage: Int = 0 {
        didSet {
            updateCurrentPageLabel(currentPage: currentPage)
            loadImages(currentPage: currentPage)
            annotationsEditorViewModel.annotationsEditor = currentPage >= 0 && currentPage < annotationsEditorPerPage
                .count
                ? annotationsEditorPerPage[currentPage]
                : nil
        }
    }

    /// Access to image view for current page, needed for custom transition
    var imageViewForCurrentPage: UIImageView? {
        guard currentPage >= 0, currentPage < pages.count else { return nil }
        return pages[currentPage].imageView
    }

    /// last page for which `loadImages` was called
    private var imagesLastLoadedForPage: Int?

    /// previous view size stored to only layout views if the size has changed
    private var previousSize: CGSize = .zero

    /// - Parameters
    ///   - imageDataProviderFactory   function returning ImageDataProvider for given PhotoKey
    ///   - photoKeys:                            array of cache key for photos
    ///   - annotations:                          array of Annotations? data for given photo (optional, there might be no annotations for a photo)
    ///   - removePhotoHandler:           if provided then a button for removing photo will be shown. This vc will remove the photo from given photo keys and animate the changes iff the handler returns `true`
    ///
    init(imageDataProviderFactory: @escaping (PhotoKey) -> RangeImageDataProvider,
         photoKeys: [PhotoKey?],
         annotations: [Annotations?],
         removePhotosEnabled: Bool)
    {
        self.imageDataProviderFactory = imageDataProviderFactory
        self.photoKeys = photoKeys
        self.removePhotosEnabled = removePhotosEnabled
        pages = photoKeys.map { _ in FullscreenImageGalleryPageView() }
        let annotationsEditorViewModel = AnnotationsEditorViewModel()
        self.annotationsEditorViewModel = annotationsEditorViewModel
        annotationsEditorPerPage = zip(pages, annotations).map { page, annotations in
            AnnotationsEditor(hostView: page, initialAnnotations: annotations, viewModel: annotationsEditorViewModel)
        }
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .Neutral_09
        view.clipsToBounds = true

        pageSeparator.backgroundColor = view.backgroundColor

        setupScrollView()
        setupButtons()
        setupCurrentPageLabel()

        pages.forEach(scrollView.addSubview)
        scrollView.addSubview(pageSeparator)

        let galleryViewScroll = FullscreenImageGalleryScrollViewRepresentable(view: scrollView)
        let galleryView = FullscreenImageGalleryView(
            annotationsEditorViewModel: annotationsEditorViewModel,
            imageGalleryView: galleryViewScroll
        )
        let galleryViewController = UIHostingController(rootView: galleryView)
        add(childController: galleryViewController)
        galleryViewController.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        galleryViewController.view.backgroundColor = .clear

        view.addSubview(currentPageLabel)
        currentPageLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(self.view.safeAreaLayoutGuide.snp.top).offset(12)
        }

        view.addSubview(confirmButton)
        confirmButton.snp.makeConstraints { make in
            make.height.equalTo(40)
            make.width.greaterThanOrEqualTo(40)
            make.centerY.equalTo(currentPageLabel)
            make.trailing.equalToSuperview().inset(16)
        }

        if removePhotosEnabled {
            view.addSubview(deleteButton)
            deleteButton.snp.makeConstraints { make in
                make.width.height.equalTo(40)
                make.centerY.equalTo(currentPageLabel)
                make.left.equalTo(currentPageLabel.snp.right).offset(8)
            }
        }

        view.addSubview(cancelButton)
        cancelButton.snp.makeConstraints { make in
            make.height.equalTo(40)
            make.width.greaterThanOrEqualTo(40)
            make.centerY.equalTo(currentPageLabel)
            make.leading.equalToSuperview().inset(16)
        }
        if let annotationsSettingsButton = annotationsSettingsButton {
            view.addSubview(annotationsSettingsButton)
            annotationsSettingsButton.snp.makeConstraints { make in
                make.width.height.equalTo(40)
                make.centerY.equalTo(currentPageLabel)
                make.right.equalTo(currentPageLabel.snp.left).offset(-8)
            }
        }

        updateCurrentPageLabel(currentPage: currentPage)
        loadImages(currentPage: currentPage)
        setupAnnotationsViewModel()
        annotationsEditorViewModel.annotationsEditor = annotationsEditorPerPage[currentPage]
    }

    private func setupScrollView() {
        scrollView.isPagingEnabled = true
        scrollView.alwaysBounceHorizontal = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.delegate = self
    }

    private func notifyOnDone() {
        let resultAnnotations = annotationsEditorPerPage.map { $0.getAnnotations() }
        onDone?(removedPhotosIndices, resultAnnotations)
    }

    private func setupButtons() {
        cancelButton = UIButton(
            configuration: FullscreenImageGalleryViewController.cancelDoneButtonConfig,
            primaryAction: UIAction(title: String(localized: "Cancel")) { [weak self] _ in
                self?.onCancel?()
            }
        )
        confirmButton = UIButton(
            configuration: FullscreenImageGalleryViewController.cancelDoneButtonConfig,
            primaryAction: UIAction(title: String(localized: "Done")) { [weak self] _ in
                self?.notifyOnDone()
            }
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateDoneButtonEnabled),
            name: AnnotationsEditor.AnnotationsUpdatedNotificationName,
            object: nil
        )
        updateDoneButtonEnabled()

        if AppConfiguration.showDebugOptions {
            annotationsSettingsButton = UIButton(
                configuration: UIButton.Configuration.iconButton(
                    backgroundColor: .Neutral_10, foregroundColor: .Neutral_04,
                    strokeColor: .Neutral_07, imagePointSize: 14
                ),
                primaryAction: UIAction(image: UIImage(systemName: "gearshape")) { [weak self] _ in
                    self?.showAnnotationsSettings()
                }
            )
        }

        deleteButton = RangeButton(
            configuration: UIButton.Configuration.iconButton(
                backgroundColor: .Neutral_10, foregroundColor: .Red_03,
                strokeColor: .Neutral_07, imagePointSize: 14
            ),
            primaryAction: UIAction(image: UIImage(systemName: "trash")) { [weak self] _ in
                self?.maybeRemovePhoto()
            }
        ).withCustomRangeHighlightColor()
    }

    @objc private func updateDoneButtonEnabled() {
        confirmButton.isEnabled = !removedPhotosIndices.isEmpty || annotationsEditorPerPage
            .contains(where: \.annotationsUpdated)
    }

    @objc private func updateDeleteButtonHidden() {
        guard let deleteButton else { return }
        deleteButton.isHidden = photoKeys.isEmpty
    }

    static var cancelDoneButtonConfig: UIButton.Configuration {
        var config = UIButton.Configuration.filled()
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        config.baseForegroundColor = .Neutral_04
        config.cornerStyle = .fixed
        config.background.cornerRadius = 20
        config.background.strokeColor = .Neutral_07
        config.background.backgroundColor = .Neutral_10
        return config
    }

    private func setupAnnotationsViewModel() {
        annotationsViewModelScribbleModeSubscriber = annotationsEditorViewModel.$gesturesMode
            .sink { [weak self] gesturesMode in
                // disable scrolling between pages when scribbling or drawing other annotations
                self?.scrollView.isScrollEnabled = gesturesMode == .normal
            }
    }

    /// Shows view controller for annotations dev settings
    private func showAnnotationsSettings() {
        let settingsVC = UIHostingController(
            rootView: AnnotationsDevSettingsView().environmentObject(annotationsSettings)
        )
        present(settingsVC, animated: true)
    }

    private func setupCurrentPageLabel() {
        currentPageLabel.textColor = .Neutral_01
        currentPageLabel.font = .preferredFont(forTextStyle: .body)
        currentPageLabel.adjustsFontForContentSizeCategory = true
    }

    override func viewDidLayoutSubviews() {
        let viewSize = view.frame.size
        if viewSize != previousSize {
            updateContentSize()

            // adjust content offset to keep the scroll view centered on the primary visible page
            // (if the user is not interacting with the scroll view, which means we're updating the frame)
            if !scrollView.isDragging, !scrollView.isDecelerating {
                scrollView.contentOffset.x = CGFloat(currentPage) * viewSize.width
            }

            updatePageFrames()
            updatePageSeparatorFrame()
        }
        previousSize = viewSize
        // to make sure that it's installed if the image is loaded before the views are layed out
        if currentPage >= 0, currentPage < annotationsEditorPerPage.count {
            annotationsEditorPerPage[currentPage].installView()
        }
    }

    override dynamic var preferredStatusBarStyle: UIStatusBarStyle {
        UIStatusBarStyle.lightContent
    }

    /// The page closest to the x offset
    private var primaryVisiblePage: Int {
        var page = scrollView.frame.width > 0
            ? (Int(scrollView.contentOffset.x + scrollView.frame.width / 2)
                / Int(scrollView.frame.width))
            : 0
        // limit page in case user scrolls to far to reach -1 or photos.count
        page = min(max(0, page), photoKeys.count - 1)
        return page
    }

    /// The progress of horizontal scrolling through pages.
    /// If it's on page 0 it's 0, then half way to 1 is 0.5, at page 1 it's 1, etc...
    private var pageOffsetFraction: Double {
        scrollView.frame.width > 0 ? scrollView.contentOffset.x / scrollView.frame.width : 0
    }

    /// Update scroll view content size based on number of pages
    private func updateContentSize() {
        scrollView.contentSize = CGSize(
            width: view.frame.width * CGFloat(photoKeys.count),
            height: view.frame.height
        )
    }

    /// set page frames based on current page size and pageOffsetFraction
    private func updatePageFrames() {
        let pageSize = view.frame.size
        pages.enumerated().forEach { index, view in
            view.frame = CGRect(
                origin: CGPoint(x: CGFloat(index) * pageSize.width, y: 0),
                size: pageSize
            )
        }
    }

    /// Calculate frame for page separator visible between pages.
    /// It covers partially the pages to give effect similar like in Photos apps.
    /// There are at most 2 pages visible at a time, so there's only 1 page separator needed.
    /// If the page takes the whole screen the separator is not visible at all
    private func updatePageSeparatorFrame() {
        let separatorWidth = 30.0
        let pageSize = view.frame.size
        let size = CGSize(width: separatorWidth, height: scrollView.frame.height)
        let page = primaryVisiblePage
        // if the current page is shifted right (negative values) or left (positive)
        let currentPageOffsetFraction = pageOffsetFraction - Double(page)

        let x = currentPageOffsetFraction >= 0
            // current page is offset left, so show the separator on the right side and start
            // overlapping the page as the offset gets bigger, so next page is being revealed
            ? Double(page + 1) * pageSize.width - currentPageOffsetFraction * separatorWidth
            // current page is offset right, so show the separator on the left side and start
            // overlapping the page as the offset gets smaller, so previous page is being revealed
            : Double(page) * pageSize.width - separatorWidth - currentPageOffsetFraction * separatorWidth

        pageSeparator.frame = CGRect(origin: CGPoint(x: x, y: 0), size: size)
    }

    private func updateCurrentPageLabel(currentPage: Int) {
        currentPageLabel.text = "\(currentPage + 1)/\(photoKeys.count)"
    }

    /// Load images so we always have 2 images loaded before the current and 2 after, so 5 in total
    /// - Parameters
    ///   - current page
    ///   - force - if true then the check for not loading again if given page was already loaded is bypassed, needed for removing pages as their indices change
    private func loadImages(currentPage: Int, force: Bool = false) {
        if currentPage != imagesLastLoadedForPage || force == true {
            pages.enumerated().forEach { index, page in
                if index < currentPage - 2 || index > currentPage + 2 {
                    page.imageView.kf.cancelDownloadTask()
                    page.imageView.image = nil
                } else {
                    guard let photoKey = photoKeys[index] else { return }
                    let rangeImageDataProvider = imageDataProviderFactory(photoKey)
                    /// we may already have the image for this page, so update the size
                    page.imageUpdated()
                    var options = rangeImageDataProvider.options
                    // keep the image (maybe we have a thumb there and now loading full, no need to go blank while loading)
                    options.append(.keepCurrentImageWhileLoading)
                    page.imageView.kf.setImage(
                        with: rangeImageDataProvider,
                        placeholder: nil,
                        options: options,
                        progressBlock: nil,
                        completionHandler: { [weak self] _ in
                            page.imageUpdated()
                            self?.annotationsEditorPerPage[index].installView()
                        }
                    )
                }
            }
        }
        imagesLastLoadedForPage = currentPage
    }

    /// Checks if this is the last photo, if so ask user to confirm and invoke "done" action when confirmed - we want to avoid a situation
    /// where the gallery presents the empty screen.
    /// If this is not the last photo then just proceed with `removePhoto`
    private func maybeRemovePhoto() {
        if photoKeys.count <= 1 {
            let alertController = UIAlertController(
                title: "Delete photo",
                message: "Are you sure you want to delete your last photo?",
                preferredStyle: .alert
            )
            alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alertController.addAction(UIAlertAction(title: "Confirm", style: .destructive) { [weak self] _ in
                self?.removePhoto()
                self?.notifyOnDone()
            })
            present(alertController, animated: true)
        } else {
            removePhoto()
        }
    }

    /// Removes the currently showing photo from view model and adjusts the layout
    private func removePhoto() {
        let photoIndexToRemove = primaryVisiblePage
        removedPhotosIndices.append(photoIndexToRemove)
        photoKeys.remove(at: photoIndexToRemove)
        annotationsEditorPerPage.remove(at: photoIndexToRemove)
        let removedPage = pages.remove(at: photoIndexToRemove)
        // animate changes
        UIView.animate(withDuration: 0.2) {
            // the removed page fades out
            removedPage.alpha = 0
            // update the scroll metrics
            self.updateContentSize()
            self.updatePageFrames()
            self.currentPage = self.primaryVisiblePage
            self.updateCurrentPageLabel(currentPage: self.currentPage)
            // force reload the images, as the indices of pages after removed page have changed
            self.loadImages(currentPage: self.currentPage, force: true)
        } completion: { _ in
            // remove the removedPage from view hierarchy
            removedPage.imageView.image = nil
            removedPage.removeFromSuperview()
        }
        updateDoneButtonEnabled()
        updateDeleteButtonHidden()
    }

    func scrollViewDidScroll(_: UIScrollView) {
        updatePageSeparatorFrame()
        // update images while scrolling, user might be scrolling with no breaks between pages
        // so we can't wait for currentPage update
        loadImages(currentPage: primaryVisiblePage)
        updateCurrentPageLabel(currentPage: primaryVisiblePage)
    }

    func scrollViewDidEndDecelerating(_: UIScrollView) {
        // only set currentPage when stationary, so it's not updated when the frame changes
        currentPage = primaryVisiblePage
        // reset non current pages zoom
        pages.enumerated().forEach { index, page in
            if index != currentPage {
                page.resetZoom()
            }
        }
    }
}
