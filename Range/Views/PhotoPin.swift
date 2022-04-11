//

import Foundation
import UIKit

/// Creates a view of a pin with a small rounded image inside
func createPhotoPin(fromImage: UIImage) -> UIImageView {
    let pinView = UIImageView(image: UIImage(named: "photopin"))
    
    let imageInset = 2.5
    let imageSize = pinView.frame.width - 2 * imageInset
    let imageView = UIImageView(image: fromImage.imageResized(toFill: imageSize))
    imageView.contentMode = .scaleToFill
    
    imageView.frame = CGRect(x: imageInset, y: imageInset, width: imageSize, height: imageSize)
    imageView.layer.cornerRadius = imageSize/2.0
    imageView.layer.borderWidth = 1
    imageView.layer.borderColor = UIColor.Secondary_03?.cgColor
    imageView.clipsToBounds = true
    pinView.addSubview(imageView)
    
    return pinView
}
