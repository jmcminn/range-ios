import PDFKit
import UIKit

protocol PDFPageScrollViewDelegate: AnyObject {
    func scrollViewDidScroll(_ scrollView: PDFPageScrollView)
    func scrollViewDidZoom(_ scrollView: PDFPageScrollView)
    func scrollViewDidEndDragging(_ scrollView: PDFPageScrollView, willDecelerate decelerate: Bool)
    func scrollViewDidEndDecelerating(_ scrollView: PDFPageScrollView)
    func scrollViewDidEndZooming(_ scrollView: PDFPageScrollView, with view: UIView?, atScale scale: CGFloat)
}

/// Scroll view controlling the zooming of PDFPage
class PDFPageScrollView: UIScrollView {
    public let pdfView: PDFPageTiledView

    // this view has the width/height ratio of the scroll view and contains the centered pdf view.
    private let contentView: UIView

    // whether the PDF should be centered if zoomed out
    private let autoCenter: Bool

    /// Delegate that is informed of important interaction events
    public weak var pdfPageScrollViewDelegate: PDFPageScrollViewDelegate?

    /// Instantiates a scrollable page view
    ///
    /// - parameter frame:            frame of the view
    /// - parameter pdfPage:          page to be displayed
    ///
    /// - returns: a freshly initialized page view
    init(frame: CGRect, pdfPage: PDFPage, autoCenter: Bool = false) {
        self.autoCenter = autoCenter

        let originalPageSize = pdfPage._sizeAdjustedForRotation(for: .mediaBox)
        let scale = min(
            frame.width / originalPageSize.width,
            frame.height / originalPageSize.height
        )
        let scaledPageRectSize = CGSize(
            width: originalPageSize.width * scale,
            height: originalPageSize.height * scale
        )

        let contentViewSize = frame.size
        let scaledPageRect = CGRect(
            origin: CGPoint(x: (contentViewSize.width - scaledPageRectSize.width) / 2,
                            y: (contentViewSize.height - scaledPageRectSize.height) / 2),
            size: scaledPageRectSize
        )

        contentView = UIView(frame: CGRect(origin: CGPoint(x: 0, y: 0), size: contentViewSize))

        // Create the TiledPDFView based on the size of the PDF page
        pdfView = PDFPageTiledView(frame: scaledPageRect, scale: scale, pdfPage: pdfPage)

        super.init(frame: frame)
        backgroundColor = .white

        let targetRect = bounds.insetBy(dx: 0, dy: 0)
        let zoomScale = zoomScaleThatFits(targetRect.size, source: bounds.size)

        minimumZoomScale = zoomScale
        maximumZoomScale = zoomScale * 32

        contentView.addSubview(pdfView)
        addSubview(contentView)
        contentSize = contentViewSize

        decelerationRate = .fast
        delegate = self
        autoresizesSubviews = true
        autoresizingMask = [.flexibleHeight, .flexibleWidth]
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Use layoutSubviews to center the PDF page in the view.
    override func layoutSubviews() {
        super.layoutSubviews()
        if autoCenter {
            // Center the image as it becomes smaller than the size of the screen.
            let contentViewSize = contentView.frame.size

            // Center horizontally.
            let xOffset: CGFloat
            if contentViewSize.width < bounds.width {
                xOffset = (bounds.width - contentViewSize.width) / 2
            } else {
                xOffset = 0
            }

            // Center vertically.
            let yOffset: CGFloat
            if contentViewSize.height < bounds.height {
                yOffset = (bounds.height - contentViewSize.height) / 2
            } else {
                yOffset = 0
            }

            contentView.frame.origin = CGPoint(x: xOffset, y: yOffset)
        }
    }

    /// Calculates the zoom scale given a target size and a source size
    ///
    /// - parameter target: size of the target rect
    /// - parameter source: size of the source rect
    ///
    /// - returns: the zoom scale of the target in relation to the source
    private func zoomScaleThatFits(_ target: CGSize, source: CGSize) -> CGFloat {
        let widthScale = target.width / source.width
        let heightScale = target.height / source.height
        return (widthScale < heightScale) ? widthScale : heightScale
    }

    /// Calculates the new zoom rect given a desired scale and a point to zoom on
    ///
    /// - parameter scale:     desired scale to zoom to
    /// - parameter zoomPoint: the reference point to zoom on
    ///
    /// - returns: a new zoom rect
    func zoomRectForScale(_ scale: CGFloat, zoomPoint: CGPoint) -> CGRect {
        // Normalize current content size back to content scale of 1.0f
        let updatedContentSize = CGSize(
            width: contentSize.width / zoomScale,
            height: contentSize.height / zoomScale
        )

        let translatedZoomPoint = CGPoint(
            x: (zoomPoint.x / bounds.width) * updatedContentSize.width,
            y: (zoomPoint.y / bounds.height) * updatedContentSize.height
        )

        // derive the size of the region to zoom to
        let zoomSize = CGSize(width: bounds.width / scale, height: bounds.height / scale)

        // offset the zoom rect so the actual zoom point is in the middle of the rectangle
        return CGRect(x: translatedZoomPoint.x - zoomSize.width / 2.0,
                      y: translatedZoomPoint.y - zoomSize.height / 2.0,
                      width: zoomSize.width,
                      height: zoomSize.height)
    }
}

extension PDFPageScrollView: UIScrollViewDelegate {
    func viewForZooming(in _: UIScrollView) -> UIView? {
        contentView
    }

    func scrollViewDidScroll(_: UIScrollView) {
        pdfPageScrollViewDelegate?.scrollViewDidScroll(self)
    }

    func scrollViewDidZoom(_: UIScrollView) {
        pdfPageScrollViewDelegate?.scrollViewDidZoom(self)
    }

    func scrollViewDidEndDragging(_: UIScrollView, willDecelerate decelerate: Bool) {
        pdfPageScrollViewDelegate?.scrollViewDidEndDragging(self, willDecelerate: decelerate)
    }

    func scrollViewDidEndDecelerating(_: UIScrollView) {
        pdfPageScrollViewDelegate?.scrollViewDidEndDecelerating(self)
    }

    func scrollViewDidEndZooming(_: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        pdfPageScrollViewDelegate?.scrollViewDidEndZooming(self, with: view, atScale: scale)
    }
}
