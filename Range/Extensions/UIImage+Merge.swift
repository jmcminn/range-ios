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

    /// Returns a new image by adding this image centered on top of a circle with given size, background and stroke color.
    func addCircleBackground(bgSize: CGSize, bgColor: UIColor, strokeColor: UIColor?) -> UIImage {
        UIGraphicsImageRenderer(size: bgSize).image { _ in
            let ovalPath = UIBezierPath(ovalIn: CGRect(origin: .zero, size: bgSize))
            bgColor.setFill()
            ovalPath.fill()
            ovalPath.addClip()
            draw(at: CGPoint(x: (bgSize.width - size.width) / 2, y: (bgSize.height - size.height) / 2))
            if let strokeColor {
                strokeColor.setStroke()
                ovalPath.lineWidth = 2 // not 1 as half of the width is clipped
                ovalPath.stroke()
            }
        }
    }
    
    func positionInImage(ofSize bgSize: CGSize, withCenterAt centerAt: CGPoint) -> UIImage {
        UIGraphicsImageRenderer(size: bgSize).image { _ in
            draw(at: CGPoint(x: centerAt.x - size.width / 2, y: centerAt.y - size.height / 2))
        }
    }
}
