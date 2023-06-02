import Foundation
import Kingfisher
import UIKit

/// Image gallery presenting photos with given PhotoKey (template).
/// It present the photos as a horizontal gallery with the center item bigger than other photos visible to the left and right (only 1 additional
/// photo per side is visible).
/// It doesn't support zooming in on the photos.
/// The class is generic over PhotoKey, it just requires imageDataProviderFactory that accepts the PhotoKey and returns
/// Kingfisher ImageDataProvider which is used to display images from cache (which cache is also internal detail of imageDataProviderFactory).
class ImageGalleryViewController<PhotoKey>: UIViewController, UIScrollViewDelegate {
    let imageDataProviderFactory: (PhotoKey) -> RangeImageDataProvider
    private var photoKeys: [PhotoKey]

    /// Photo selected, the index available in the `currentPage`
    var onPhotoSelected: (() -> Void)?
    var onAnnotationsSelected: (() -> Void)?
    var onPSPDFKITAnnotationsSelected: (() -> Void)?

    // this defines the page size
    let pageHeight2Width: Double

    /// Handler that accepts removal of photo at given index by returning `true`
    let removePhotoHandler: ((Int) -> Bool)?

    private let scrollView = UIScrollView()
    private var pages: [ImageGalleryPageView] = []
    private var pageSize: CGSize = .zero
    private(set) var currentPage: Int = 0 {
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

    /// - Parameters
    ///   - imageDataProviderFactory   function returning ImageDataProvider for given PhotoKey
    ///   - photoKeys:                            array of PhotoKey
    ///   - pageHeight2Width                 defines the image gallery page aspect ratio
    ///   - removePhotoHandler:           if provided then a button for removing photo will be shown. This vc will remove the photo from given photo keys and animate the changes iff the handler returns `true`
    init(imageDataProviderFactory: @escaping (PhotoKey) -> RangeImageDataProvider,
         photoKeys: [PhotoKey], pageHeight2Width: Double, removePhotoHandler: ((Int) -> Bool)? = nil)
    {
        self.imageDataProviderFactory = imageDataProviderFactory
        self.photoKeys = photoKeys
        self.pageHeight2Width = pageHeight2Width
        self.removePhotoHandler = removePhotoHandler
        super.init(nibName: nil, bundle: nil)

        pages = photoKeys.map { _ in self.setupPage() }
    }

    private func setupPage() -> ImageGalleryPageView {
        ImageGalleryPageView(
            onPageTap: { [weak self] in
                self?.onPhotoSelected?()
            },
            onAnnotationsTap: { [weak self] in
                self?.onAnnotationsSelected?()
            },
            onPSPDFKITAnnotationsTap: { [weak self] in
                self?.onPSPDFKITAnnotationsSelected?()
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
        photoKeys.remove(at: index)
        let removedPage = pages.remove(at: index)
        removedPage.imageView.image = nil
        removedPage.removeFromSuperview()
        // force the view layout
        previousSize = .zero
        view.setNeedsLayout()
        view.layoutIfNeeded()
        // and reloading of images
        currentPage = primaryVisiblePage
        // last was deleted, then scroll to previous
        if currentPage >= photoKeys.count {
            setCurrentPage(photoKeys.count - 1)
        }
        loadImages(currentPage: currentPage, force: true)
    }

    /// Sets the current page by updating the offset
    func setCurrentPage(_ page: Int, animated: Bool = false) {
        scrollView.setContentOffset(CGPoint(x: CGFloat(page) * pageSize.width, y: 0), animated: animated)
        currentPage = page
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
        pages.forEach(scrollView.addSubview)
        // set some initial height to width ratio but finally it's set when the image is loaded
        pages.forEach { $0.imageHeight2Width = pageHeight2Width }

        loadImages(currentPage: currentPage)
    }

    override func viewDidLayoutSubviews() {
        pageSize = calculatePageSize()

        if pageSize != previousSize {
            let pageFrame = CGRect(
                x: view.center.x - pageSize.width / 2.0,
                y: view.center.y - pageSize.height / 2.0,
                width: pageSize.width,
                height: pageSize.height
            )

            scrollView.frame = pageFrame
            scrollView.contentSize = CGSize(
                width: pageSize.width * CGFloat(photoKeys.count),
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
            view.imageInset = UIEdgeInsets(
                top: inset,
                left: isLeft ? 2 * inset : 0,
                bottom: inset,
                right: isLeft ? 0 : 2 * inset
            )
            view.setNeedsLayout()
        }
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
                    let rangeImageDataProvider = imageDataProviderFactory(photoKeys[index])
                    page.imageView.kf.setImage(
                        with: rangeImageDataProvider,
                        placeholder: nil, options: [.targetCache(rangeImageDataProvider.cache)], progressBlock: nil,
                        completionHandler: { result in
                            // invalidate layout to recalculate aspect ratio after the image is loaded
                            if case let .success(imageResult) = result {
                                page.imageHeight2Width = imageResult.image.size.height / imageResult.image.size.width
                            }
                        }
                    )
                }
            }
        }
        imagesLastLoadedForPage = currentPage
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
        return pages[currentPage]
    }

    /// Access to image view for current page, needed for custom transition
    var imageViewForCurrentPage: UIImageView? {
        viewForCurrentPage?.imageView
    }
}
