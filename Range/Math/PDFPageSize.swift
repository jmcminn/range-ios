import Foundation
import PDFKit

extension PDFPage {
    /// Uses bounds(for box) but swaps width/height if rotation is 90 or 270
    func _sizeAdjustedForRotation(for box: PDFDisplayBox) -> CGSize {
        let bounds = bounds(for: box)
        if rotation == 90 || rotation == 270 {
            // swap width and height if rotated
            return CGSize(width: bounds.height, height: bounds.width)
        } else {
            return bounds.size
        }
    }

    func sizeInMeters(forScale scale: Double) -> CGSize {
        let point2Inch = 1 / 72.0
        let inch2Meter = 0.0254
        let metersPerPoint = point2Inch * inch2Meter
        let pageSize = _sizeAdjustedForRotation(for: .mediaBox)
        let widthInMeters = Double(pageSize.width) * metersPerPoint / scale
        let heightInMeters = Double(pageSize.height) * metersPerPoint / scale
        return CGSize(width: widthInMeters, height: heightInMeters)
    }
}
