import Foundation
import UIKit

/// Resize given image data to not extend maxResolution.
/// Keep the metadata while resizing.
/// If resizing fails for any reason it returns nil
/// If the image size is not bigger than the maxResolution it returns *this data* (no operation is performed)
func resizeImage(imageData: Data?, maxResolution: Int) -> Data? {
    guard let imageData = imageData else {
        return nil
    }

    // create image source from jpeg data
    guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil) else { return nil }
    guard let type = CGImageSourceGetType(imageSource) else { return nil }
    guard let metadata = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any]
    else { return nil }
    guard
        let width = metadata[kCGImagePropertyPixelWidth as String] as? Int,
        let height = metadata[kCGImagePropertyPixelHeight as String] as? Int else { return nil }
    let maxSourceResolution = max(width, height)
    if maxSourceResolution > maxResolution {
        let scaleOptions = [kCGImageSourceThumbnailMaxPixelSize as String: maxResolution,
                            kCGImageSourceCreateThumbnailFromImageAlways as String: true] as [String: Any]
        guard let scaledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, scaleOptions as CFDictionary)
        else { return nil }
        let newImageData = NSMutableData()
        // create new jpeg
        guard let cgImageDestination = CGImageDestinationCreateWithData(newImageData, type, 1, nil)
        else { return nil }

        CGImageDestinationAddImage(
            cgImageDestination,
            scaledImage,
            metadata as CFDictionary
        )
        CGImageDestinationFinalize(cgImageDestination)

        return newImageData as Data
    } else {
        return imageData
    }
}

/// extension for resizing UIImage
/// Please note that using UIImage for resizing photos taken on the iPhone will not preserve the (exif) metadata, as this metadata
/// is not present in UIImage
extension UIImage {
    /// resizes image proportionally to get image with given width
    func imageResized(toWidth width: CGFloat) -> UIImage {
        let targetSize = CGSize(width: width, height: width * size.height / size.width)
        return UIGraphicsImageRenderer(size: targetSize).image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    /// resizes image proportionally to fill given widthOrHeight (the smaller of width and height of the original image)
    func imageResized(toFill heightOrWidth: CGFloat) -> UIImage {
        let targetSize = size.height > size.width
            ?
            CGSize(width: heightOrWidth,
                   height: heightOrWidth * size.height / size
                       .width) // scale based on width if height bigger
            : CGSize(width: heightOrWidth * size.width / size.height, height: heightOrWidth)

        return UIGraphicsImageRenderer(size: targetSize).image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
