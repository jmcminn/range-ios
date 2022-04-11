import Foundation
import UIKit

extension UIImage {
    /// resizes image proportionally to get image with given width
    func imageResized(toWidth width: CGFloat) -> UIImage {
        let targetSize = CGSize(width: width, height: width*size.height/size.width)
        return UIGraphicsImageRenderer(size: targetSize).image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
    
    /// resizes image proportionally to fill given widthOrHeight (the smaller of width and height of the original image)
    func imageResized(toFill heightOrWidth: CGFloat) -> UIImage {
        let targetSize = size.height > size.width
        ? CGSize(width: heightOrWidth, height: heightOrWidth*size.height/size.width) // scale based on width if height bigger
        : CGSize(width: heightOrWidth*size.width/size.height, height: heightOrWidth)
        
        return UIGraphicsImageRenderer(size: targetSize).image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
