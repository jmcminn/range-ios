import Foundation
import Kingfisher
import UIKit

/// Image gallery presenting photos with given PhotoKey (template).
/// It present the photos as a horizontal gallery with the center item bigger than other photos visible to the left and right (only 1 additional
/// photo per side is visible).
/// It doesn't support zooming in on the photos.
/// The class is generic over PhotoKey, it just requires imageDataProviderFactory that accepts the PhotoKey and returns
/// Kingfisher ImageDataProvider which is used to display images from cache (which cache is also internal detail of imageDataProviderFactory).
class ImageGalleryViewController<PhotoKey: Equatable>: UIViewController, UIScrollViewDelegate {
    let imageDataProviderFactory: (PhotoKey) -> RangeImageDataProvider
    private var photoKeys: [PhotoKey?]

    /// Photo selected, the index available in the `currentPage`
    var onPhotoSelected: (() -> Void)?
    var onAnnotationsSelected: (() -> Void)?
    /// When set each card will display a "..." button and call this action when tapped (sourceView will be passed)
    var onMoreAction: ((UIView) -> Void)?
    /// When set each card will display a share button and call this action when tapped (sourceView will be passed)
    var onShareAction: ((UIView) -> Void)?
    /// if set there'll be a special last page added to the gallery for updating the photo (this is for the versioned/correlated photos case)
    var onUpdatePhotoAction: (() -> Void)?

    // this defines the page size
    let pageHeight2Width: Double

    /// Handler that accepts removal of photo at given index by returning `true`
    let removePhotoHandler: ((Int) -> Bool)?

    private let scrollView = UIScrollView()
    private var pages: [UIView] = []
    private var pageSize: CGSize = .zero
    @objc private(set) dynamic var currentPage: Int = 0 {
        didSet {
            if currentPage != oldValue {
                loadImages(currentPage: currentPage)
            }
        }
    }

    /// last page for which `loadImages` was called
    var imagesLastLoadedForPage: Int?

    /// last size for which it calculated the layout, and only recalculate if it has changed
    var previousSize: CGSize = .zero

    /// Whether to label the photos with version (from1 to n, left to right)
    var showVersions: Bool = false

    /// - Parameters
    ///   - imageDataProviderFactory   function returning ImageDataProvider for given PhotoKey
    ///   - photoKeys:                            array of PhotoKey
    ///   - pageHeight2Width                 defines the image gallery page aspect ratio
    ///   - removePhotoHandler:           if provided then a button for removing photo will be shown. This vc will remove the photo from given photo keys and animate the changes iff the handler returns `true`
    init(imageDataProviderFactory: @escaping (PhotoKey) -> RangeImageDataProvider,
         photoKeys: [PhotoKey?], pageHeight2Width: Double, removePhotoHandler: ((Int) -> Bool)? = nil)
    {
        self.imageDataProviderFactory = imageDataProviderFactory
        self.photoKeys = photoKeys
        self.pageHeight2Width = pageHeight2Width
        self.removePhotoHandler = removePhotoHandler
        super.init(nibName: nil, bundle: nil)

        pages = photoKeys.map { _ in self.setupPage() }
    }

    /// Update photo key at given index and reload the image
    func updatePhotoKey(_ photoKey: PhotoKey?, atIndex index: Int) {
        if photoKey != photoKeys[index] {
            photoKeys[index] = photoKey
            // photo key has changed, force reload
            loadImage(atIndex: index, force: true)
        }
    }

    private func setupPage() -> ImageGalleryPageView {
        ImageGalleryPageView(
            onPageTap: { [weak self] in
                self?.onPhotoSelected?()
            },
            onAnnotationsTap: { [weak self] in
                self?.onAnnotationsSelected?()
            },
            onPhotoRemove: removePhotoHandler != nil
                ? { [weak self] in
                    guard let self = self else { return }
                    _ = self.removePhotoHandler?(self.currentPage)
                }
                : nil
        )
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// callback for photo removed at index, removes the photo key, page and recalculates layout and images
    func photoRemoved(atIndex index: Int) {
        let currentPageBeforeRemoval = primaryVisiblePage
        photoKeys.remove(at: index)
        let removedPage = pages.remove(at: index)
        (removedPage as? ImageGalleryPageView)?.imageView.image = nil
        removedPage.removeFromSuperview()
        updatePageVersions()
        // force the view layout
        previousSize = .zero
        view.setNeedsLayout()
        view.layoutIfNeeded()
        // and reloading of images
        currentPage = primaryVisiblePage
        // page before the current page was removed, we want to keep the visible page, not the index, so
        // we need to decrement the page (user was looking at image at page 2, image at page 0 was removed, it means
        // that user should be looking at the same image which is now at page 1)
        if index < currentPageBeforeRemoval {
            setCurrentPage(currentPage - 1)
        }
        // last was deleted, then scroll to previous
        if currentPage >= photoKeys.count, photoKeys.count > 0 {
            setCurrentPage(photoKeys.count - 1)
        }
        loadImages(currentPage: currentPage, force: true)
    }

    func addPhoto(_ photoKey: PhotoKey?, atIndex index: Int) {
        photoKeys.insert(photoKey, at: index)
        let page = setupPage()
        page.imageHeight2Width = pageHeight2Width
        if onMoreAction != nil {
            page.onMoreAction = { [weak self, weak page] in
                guard let self, let page else { return }
                self.onMoreAction?(page.moreButton ?? page)
            }
        }
        if onShareAction != nil {
            page.onShareAction = { [weak self, weak page] in
                guard let self, let page else { return }
                self.onShareAction?(page.shareButton ?? page)
            }
        }
        pages.insert(page, at: index)
        scrollView.addSubview(page)
        updatePageVersions()
        // force the view layout
        previousSize = .zero
        view.setNeedsLayout()
        view.layoutIfNeeded()
        loadImage(atIndex: index)
        loadImages(currentPage: currentPage, force: true)
    }

    private func updatePageVersions() {
        guard showVersions else { return }
        for (index, page) in pages.enumerated() {
            if let page = page as? ImageGalleryPageView {
                page.showVersion(index + 1)
            }
        }
    }

    /// Sets the current page by updating the offset
    func setCurrentPage(_ page: Int, animated: Bool = false) {
        scrollView.setContentOffset(CGPoint(x: CGFloat(page) * pageSize.width, y: 0), animated: animated)
        currentPage = page
    }

    func setCurrentPage(forPhotoKey photoKey: PhotoKey, animated: Bool = false) {
        guard let pageIndex = photoKeys.firstIndex(of: photoKey) else { return }
        setCurrentPage(pageIndex, animated: animated)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .dynamic(.Neutral_10)
        view.clipsToBounds = true

        scrollView.delegate = self
        scrollView.isPagingEnabled = true
        scrollView.alwaysBounceHorizontal = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        // TODO: for RTL
//                if UIApplication.shared.userInterfaceLayoutDirection == .rightToLeft {
//                    scrollView.transform = CGAffineTransform(rotationAngle: CGFloat(Double.pi))
//                }
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.clipsToBounds = false // show pages that are out of bounds

        view.addSubview(scrollView)

        if onUpdatePhotoAction != nil {
            let updatePhotoPage = ImageGalleryUpdatePhotoPageView()
            updatePhotoPage.onUpdatePhotoAction = onUpdatePhotoAction
            pages.append(updatePhotoPage)
        }

        pages.forEach(scrollView.addSubview)
        // set some initial height to width ratio but finally it's set when the image is loaded
        pages.compactMap { $0 as? ImageGalleryPageView }
            .forEach { pageView in
                pageView.imageHeight2Width = pageHeight2Width
                if onMoreAction != nil {
                    pageView.onMoreAction = { [weak self, weak pageView] in
                        guard let self, let pageView else { return }
                        self.onMoreAction?(pageView.moreButton ?? pageView)
                    }
                }
                if onShareAction != nil {
                    pageView.onShareAction = { [weak self, weak pageView] in
                        guard let self, let pageView else { return }
                        self.onShareAction?(pageView.shareButton ?? pageView)
                    }
                }
            }

        loadImages(currentPage: currentPage)

        updatePageVersions()
    }

    override func viewDidLayoutSubviews() {
        pageSize = calculatePageSize()

        if pageSize != previousSize {
            let pageFrame = CGRect(
                x: (view.bounds.width - pageSize.width) / 2.0,
                y: (view.bounds.height - pageSize.height) / 2.0,
                width: pageSize.width,
                height: pageSize.height
            )

            scrollView.frame = pageFrame
            scrollView.contentSize = CGSize(
                width: pageSize.width * CGFloat(pages.count),
                height: pageSize.height
            )

            // adjust content offset to keep the scroll view centered on the primary visible page
            // (if the user is not interacting with the scroll view, which means we're updating the frame)
            if !scrollView.isDragging, !scrollView.isDecelerating {
                scrollView.contentOffset.x = CGFloat(currentPage) * pageSize.width
            }

            updatePageFrames()
            updatePageImageInsets()
        }
        previousSize = pageSize
    }

    /// recalculate page size, etc. based on the current frame size page size ratio
    private func calculatePageSize() -> CGSize {
        // the width depends on the height2Width ratio + horizontal margins of 8, but cannot be
        // bigger than view width
        let width = min(
            view.frame.width,
            view.frame.height / pageHeight2Width + 2 * 8
        )
        let pageSize = CGSize(width: Int(width), height: Int(view.frame.height))
        return pageSize
    }

    /// The page closest to the x offset
    private var primaryVisiblePage: Int {
        pageSize.width > 0
            ? Int(scrollView.contentOffset.x + pageSize.width / 2) / Int(pageSize.width)
            : 0
    }

    /// The progress of horizontal scrolling through pages.
    /// If it's on page 0 it's 0, then half way to 1 is 0.5, at page 1 it's 1, etc...
    private var pageOffsetFraction: Double {
        pageSize.width > 0 ? scrollView.contentOffset.x / pageSize.width : 0
    }

    /// set page frames based on current page size and pageOffsetFraction
    private func updatePageFrames() {
        pages.enumerated().forEach { index, view in
            view.frame = CGRect(
                x: CGFloat(index) * pageSize.width,
                y: 0,
                width: pageSize.width,
                height: pageSize.height
            )
        }
    }

    /// Set the page imageInsets based on pageOffsetFracton
    /// The images for pages are lower when they are more far away from visible center
    /// "1 page away" = 30 points inset
    /// Additionally if the page is to the left from the center inset it's image from the left, so it "glues" to the center. The goal is to make it
    /// smaller in both dimensions, not only height, so the image fill looks better (actually zooming in/out the photo and not just clipping top/bottom)
    private func updatePageImageInsets() {
        let offsetFraction = pageOffsetFraction
        pages.enumerated().forEach { index, view in
            let inset = 30 * abs(Double(index) - offsetFraction)
            let isLeft: Bool = offsetFraction > Double(index)
            let pageInset = UIEdgeInsets(
                top: inset,
                left: isLeft ? 2 * inset : 0,
                bottom: inset,
                right: isLeft ? 0 : 2 * inset
            )
            if let page = view as? ImageGalleryPageView {
                page.pageInset = pageInset
                page.setNeedsLayout()
            } else if let page = view as? ImageGalleryUpdatePhotoPageView {
                page.pageInset = pageInset
            }
        }
    }

    /// Load images so we always have 2 images loaded before the current and 2 after, so 5 in total
    /// - Parameters
    ///   - current page
    ///   - force - if true then the check for not loading again if given page was already loaded is bypassed, needed for adding/removing pages as their indices change
    private func loadImages(currentPage: Int, force: Bool = false) {
        if currentPage != imagesLastLoadedForPage || force == true {
            pages.enumerated().forEach { index, page in
                guard let page = page as? ImageGalleryPageView else { return }
                if index < currentPage - 2 || index > currentPage + 2 {
                    page.imageView.kf.cancelDownloadTask()
                    page.imageView.image = nil
                } else {
                    loadImage(atIndex: index)
                }
            }
        }
        imagesLastLoadedForPage = currentPage
    }

    ///
    /// - Parameters:
    ///    - index
    ///    - force when `true` load even if the page already has an image loaded, otherwise load only if no image set
    private func loadImage(atIndex index: Int, force: Bool = false) {
        guard let photoKey = photoKeys[index] else { return }
        let rangeImageDataProvider = imageDataProviderFactory(photoKey)
        guard let page = pages[index] as? ImageGalleryPageView else { return }
        if !force, page.imageView.image != nil {
            // not forced, image already there => nothing to do
            return
        }
        page.imageView.kf.setImage(
            with: rangeImageDataProvider,
            placeholder: nil, options: rangeImageDataProvider.options, progressBlock: nil,
            completionHandler: { result in
                // invalidate layout to recalculate aspect ratio after the image is loaded
                if case let .success(imageResult) = result {
                    page.imageHeight2Width = imageResult.image.size.height / imageResult.image
                        .size.width
                }
            }
        )
    }

    func scrollViewDidScroll(_: UIScrollView) {
        updatePageImageInsets()
        // update images while scrolling, user might be scrolling with no breaks between pages
        // so we can't wait for currentPage update
        loadImages(currentPage: primaryVisiblePage)
    }

    func scrollViewDidEndDecelerating(_: UIScrollView) {
        // only set currentPage when stationary, so it's not updated when the frame changes
        currentPage = primaryVisiblePage
    }
}

/// Transitioning
extension ImageGalleryViewController {
    /// Access to view for current page, needed for custom transition
    var viewForCurrentPage: ImageGalleryPageView? {
        guard currentPage >= 0, currentPage < pages.count else { return nil }
        return pages[currentPage] as? ImageGalleryPageView
    }

    /// Access to image view for current page, needed for custom transition
    var imageViewForCurrentPage: UIImageView? {
        viewForCurrentPage?.imageView
    }
}
