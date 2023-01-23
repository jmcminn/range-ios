import Foundation
import Photos
import UIKit

/// This extension exists to wrap UIImageWriteToSavedPhotosAlbum and expose as async function
extension UIImage {
    /// Writes this image to saved photos (camera roll if the device has camera) and throws in case of errors.
    func _writeToSavedPhotosAlbum() async throws {
        try await withUnsafeThrowingContinuation { continuation in
            let writer = ImageWriter(image: self) { error in
                if let error = error {
                    if PHPhotoLibrary.authorizationStatus(for: .addOnly) == .denied {
                        // in case of the denied access to photo library the error from UIImageWriteToSavedPhotosAlbum
                        // isn't very descriptive, it says "Unknown error"
                        continuation.resume(throwing: "Access to photo library is denied.")
                    } else {
                        continuation.resume(throwing: error)
                    }
                } else {
                    continuation.resume()
                }
            }
            writer.writeToSavedPhotosAlbum()
        } as Void
    }

    /// Wrap UIImageWriteToSavedPhotosAlbum to convert from completion selector based to a completion callback based.
    /// This a run-once class. It get's all the parameters in the constructor and expects `writeToSavePhotosAlbum` called once.
    fileprivate class ImageWriter: NSObject {
        private unowned let image: UIImage
        private let completion: (Error?) -> Void

        /// - Parameters:
        ///   - image - the image to save to camera roll
        ///   - completion - completion callback called when the `writeToSavedPhotosAlbum` finishes
        init(image: UIImage, completion: @escaping (Error?) -> Void) {
            self.image = image
            self.completion = completion
        }

        func writeToSavedPhotosAlbum() {
            UIImageWriteToSavedPhotosAlbum(image, self, #selector(imageWritten), nil)
        }

        /// Implementation UIImageWriteToSavedPhotosAlbum completionSelector
        @objc private func imageWritten(
            _: UIImage,
            error: Error?,
            context _: UnsafeMutableRawPointer?
        ) {
            DispatchQueue.main.async {
                self.completion(error)
            }
        }
    }
}
