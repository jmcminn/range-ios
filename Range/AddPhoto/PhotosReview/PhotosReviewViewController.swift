import Foundation
import Kingfisher
import UIKit

// implementation loosely based on https://github.com/zvonicek/ImageSlideshow

/// Image gallery presenting the photos as a horizontal scroll with only 1 image visible at a time and taking the full width.
/// It allows for removing photos.
/// It supports zooming in on the photos.
/// It uses `pageSeparator` overlayed on top of the page views to create a moving border between photos that is giving the impression
/// that the pages are changing width (see the iPhone Photos app for how it works). In fact the pages are layed out next to each other
/// but the separator, that has the same color as the view background, create distance between them (and make the photos look narrower.
/// just like in the Photos app)
class PhotosReviewViewController: UIViewController {
    unowned let imageCaches: ImageCaches
    let photosViewModel: PhotosToAddViewModel

    var onDone: (() -> Void)?

    /// views representing pages for images
    private var pages: [PhotosReviewPageView]
    /// a black stripe overlayed on top of pages that adds a separation between 2 visible pages
    private let pageSeparator = UIView()
    let scrollView = UIScrollView()
    private let currentPageLabel = UILabel()
    private var deleteButton: UIButton!
    private var confirmButton: UIButton!

    /// Transitioning delegate to manage the transition to this controller
    var photosReviewTransitioningDelegate: PhotosReviewTransitioningDelegate?

    var currentPage: Int = 0 {
        didSet {
            if currentPage != oldValue {
                updateCurrentPageLabel(currentPage: currentPage)
                loadImages(currentPage: currentPage)
            }
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
    ///   - imageCaches   for getting the image provider
    ///   - photos:             photos to display
    init(imageCaches: ImageCaches, photosViewModel: PhotosToAddViewModel) {
        self.imageCaches = imageCaches
        self.photosViewModel = photosViewModel
        pages = photosViewModel.photos.map { _ in PhotosReviewPageView() }
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .Neutral_10
        view.clipsToBounds = true

        pageSeparator.backgroundColor = view.backgroundColor

        setupScrollView()
        setupButtons()
        setupCurrentPageLabel()

        view.addSubview(scrollView)
        pages.forEach(scrollView.addSubview)
        scrollView.addSubview(pageSeparator)

        view.addSubview(currentPageLabel)
        view.addSubview(deleteButton)
        view.addSubview(confirmButton)

        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        deleteButton.snp.makeConstraints { make in
            make.width.height.equalTo(48)
            make.right.equalTo(self.view.snp.centerX).offset(-8)
            make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottom).offset(-16)
        }
        confirmButton.snp.makeConstraints { make in
            make.width.height.equalTo(48)
            make.left.equalTo(self.view.snp.centerX).offset(8)
            make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottom).offset(-16)
        }
        currentPageLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(self.view.safeAreaLayoutGuide.snp.top).offset(12)
        }

        updateCurrentPageLabel(currentPage: currentPage)
        loadImages(currentPage: currentPage)
    }

    private func setupScrollView() {
        scrollView.isPagingEnabled = true
        scrollView.alwaysBounceHorizontal = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.delegate = self
    }

    private func setupButtons() {
        deleteButton = UIButton(
            configuration: UIButton.Configuration.iconButton(
                backgroundColor: .Red_03, strokeColor: .Red_04
            ),
            primaryAction: UIAction(image: UIImage(systemName: "trash")) { [weak self] _ in
                self?.removePhoto()
            }
        )
        confirmButton = UIButton(
            configuration: UIButton.Configuration.iconButton(
                backgroundColor: .Green_03, strokeColor: .Green_04
            ),
            primaryAction: UIAction(image: UIImage(systemName: "checkmark")) { [weak self] _ in
                self?.onDone?()
            }
        )
    }

    private func setupCurrentPageLabel() {
        let font = UIFont.preferredFont(forTextStyle: .body)
        let boldFont = UIFont(descriptor: font.fontDescriptor.withSymbolicTraits(.traitBold)!, size: 0)
        currentPageLabel.textColor = .Neutral_04
        currentPageLabel.font = boldFont
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
        page = min(max(0, page), photosViewModel.photos.count - 1)
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
            width: view.frame.width * CGFloat(photosViewModel.photos.count),
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
        currentPageLabel.text = "\(currentPage + 1)/\(photosViewModel.photos.count)"
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
                    let rangeImageDataProvider = imageCaches
                        .imageProvider(forLocalPhotoWithCacheKey: photosViewModel.photos[index].cacheKey)
                    page.imageView.kf.setImage(
                        with: rangeImageDataProvider,
                        placeholder: nil, options: [.targetCache(rangeImageDataProvider.cache)], progressBlock: nil,
                        completionHandler: { _ in
                            page.imageUpdated()
                        }
                    )
                }
            }
        }
        imagesLastLoadedForPage = currentPage
    }

    /// Removes the currently showing photo from view model and adjusts the layout
    private func removePhoto() {
        guard !photosViewModel.photos.isEmpty else { return }
        let photoIndexToRemove = primaryVisiblePage
        photosViewModel.remove(photoAtIndex: photoIndexToRemove)
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
    }
}

extension PhotosReviewViewController: UIScrollViewDelegate {
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
