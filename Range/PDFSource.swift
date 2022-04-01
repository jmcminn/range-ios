import CoreLocation
import Foundation
import PDFKit

/// Model class to describe the displayed PDF (page). This is only a temporary solution for the demo PDF setup.
class PDFSource {
    let center: CLLocationCoordinate2D
    let page: PDFPage
    let scale: Double
    
    init(center: CLLocationCoordinate2D, page: PDFPage, scale: Double) {
        self.center = center
        self.page = page
        self.scale = scale
    }
    
}
