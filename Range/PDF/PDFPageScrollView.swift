//
//  PDFPageScrollView.swift
//  Range
//
//  Created by raho on 18/03/2022.
//

// Based on https://github.com/Alua-Kinzhebayeva/iOS-PDF-Reader
// If more sophisticated scroll view behavior is needed resembing the ImageScrollView here's a good repo: https://github.com/ssamadgh/PhotoScroller_Starter_Sample_Code_Part_III

import PDFKit
import UIKit

/// Scroll view controlling the zooming of PDFPage
class PDFPageScrollView: UIScrollView {
    public let pdfView: PDFPageTiledView
    
    /// Instantiates a scrollable page view
    ///
    /// - parameter frame:            frame of the view
    /// - parameter pdfPage:          page to be displayed
    ///
    /// - returns: a freshly initialized page view
    init(frame: CGRect, pdfPage: PDFPage) {
        let originalPageRect = pdfPage.bounds(for: .mediaBox)
        let scale = min(frame.width/originalPageRect.width, frame.height/originalPageRect.height)
        
        let scaledPageRectSize = CGSize(width: originalPageRect.width * scale, height: originalPageRect.height * scale)
        let scaledPageRect = CGRect(origin: originalPageRect.origin, size: scaledPageRectSize)
        
        // Create the TiledPDFView based on the size of the PDF page
        pdfView = PDFPageTiledView(frame: scaledPageRect, scale: scale, pdfPage: pdfPage)
        
        super.init(frame: frame)
        self.backgroundColor = .white
        
        self.contentInsetAdjustmentBehavior = .never
        
        let targetRect = bounds.insetBy(dx: 0, dy: 0)
        let zoomScale = zoomScaleThatFits(targetRect.size, source: bounds.size)
        
        minimumZoomScale = zoomScale
        maximumZoomScale = zoomScale * 16
        
        self.contentSize = scaledPageRectSize
        addSubview(pdfView)
        
        decelerationRate = .fast
        delegate = self
        autoresizesSubviews = true
        autoresizingMask = [.flexibleHeight, .flexibleWidth]
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Use layoutSubviews to center the PDF page in the view.
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Center the image as it becomes smaller than the size of the screen.
        let contentViewSize = pdfView.frame.size
        
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
        
        pdfView.frame.origin = CGPoint(x: xOffset, y: yOffset)
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
    private func zoomRectForScale(_ scale: CGFloat, zoomPoint: CGPoint) -> CGRect {
        // Normalize current content size back to content scale of 1.0f
        let updatedContentSize = CGSize(width: contentSize.width/zoomScale, height: contentSize.height/zoomScale)
        
        let translatedZoomPoint = CGPoint(x: (zoomPoint.x / bounds.width) * updatedContentSize.width,
                                          y: (zoomPoint.y / bounds.height) * updatedContentSize.height)
        
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
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return pdfView
    }
}
