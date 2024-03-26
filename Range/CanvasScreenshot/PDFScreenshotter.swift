import Foundation
import PDFKit
import UIKit

/// Converts PDFPage selected area to JPG
class PDFScreenshotter {
    /// Converts the selected frame from given page to JPEG.
    /// - Parameters:
    ///   - page - the PDF page to convert
    ///   - selectedFrame - a frame to screenshot in PDF .mediaBox unit. The frame may be outside of the .mediaBox bounds - white background will be added
    func takeScreenshot(page: PDFPage, selectedFrame: CGRect) -> UIImage {
        // the size reported by the PDF page (unrelated to view rendering)
        let pageBounds = page.bounds(for: .mediaBox)
        // Scale from the selected frame size to the expected image size
        // If pdf selection is 400x300 but we want a 4096px wide image then scale is 10.24 (4096/400)
        // This is needed to render images in constant resolution and not depending on the
        // size (in PDF units) of selected PDF are
        let scale = 4096.0 / max(selectedFrame.width, selectedFrame.height)
        let imageSize = CGSize(
            width: selectedFrame.size.width * scale,
            height: selectedFrame.size.height * scale
        )
        let renderer = UIGraphicsImageRenderer(
            size: imageSize,
            // keep the original scale (changing the scale here would change the image resolution):
            format: UIGraphicsImageRendererFormat(for: UITraitCollection(displayScale: 1))
        )
        let img = renderer.image { ctx in
            UIColor.white.set()
            // fill the background
            ctx.fill(CGRect(origin: .zero, size: imageSize))

            // PDF has (0,0) in the bottom left
            ctx.cgContext.translateBy(
                x: scale * -selectedFrame.origin.x, // offset according to selection offset
                y: scale * (-selectedFrame.origin.y + pageBounds.height) // offset
            )
            // -1 for y and a special offset above (pageBounds.height) are to mirror the PDF
            ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
            // match the img scale
            ctx.cgContext.scaleBy(x: scale, y: scale)

            page.draw(with: .mediaBox, to: ctx.cgContext)
        }
        return img
    }
}
