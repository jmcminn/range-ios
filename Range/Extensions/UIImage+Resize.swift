import Foundation
import UIKit

extension UIImage {
    func imageResized(toWidth width: CGFloat) -> UIImage {
        let targetSize = CGSize(width: width, height: width*size.height/size.width)
        return UIGraphicsImageRenderer(size: targetSize).image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
