import Foundation
import UIKit

/// Extension for merging 2 images
extension UIImage {
    /// This functions merges this image with the provided topImage (rendering the topImage on top of this image)
    func mergeWith(topImage: UIImage?) -> UIImage {
        guard let topImage = topImage else { return self }

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            let drawRect = CGRect(origin: .zero, size: size)
            self.draw(in: drawRect)
            topImage.draw(in: drawRect)
        }
    }
}
