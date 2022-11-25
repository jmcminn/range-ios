import Foundation
import PDFKit

extension PDFPage {
    func sizeInMeters(forScale scale: Double) -> CGSize {
        let point2Inch = 1 / 72.0
        let inch2Meter = 0.0254
        let metersPerPoint = point2Inch * inch2Meter
        let pageBounds = bounds(for: .mediaBox)
        let widthInMeters = Double(pageBounds.width) * metersPerPoint / scale
        let heightInMeters = Double(pageBounds.height) * metersPerPoint / scale
        return CGSize(width: widthInMeters, height: heightInMeters)
    }
}
