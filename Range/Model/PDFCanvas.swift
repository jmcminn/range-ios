import CoreLocation
import Foundation
import PDFKit

/// Model class to describe the PDF canvas.
class PDFCanvas {
    let center: CLLocationCoordinate2D
    let page: PDFPage
    let scale: Double

    init(center: CLLocationCoordinate2D, page: PDFPage, scale: Double) {
        self.center = center
        self.page = page
        self.scale = scale
    }
}
