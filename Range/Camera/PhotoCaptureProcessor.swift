import Foundation
import Photos

/// # PhotoCaptureProcessor
///
/// PhotoCaptureProcessor is a delegate for AVCapturePhotoCapture that's used by ``CameraService``.
///
/// ## API
///
/// To keep PhotoCaptureProcessor generic, it expects an AVCapturePhotoSettings and three callbacks of its own:
///
/// - willCapturePhotoAnimation called from willCapturePhotoFor delegate method
/// - photoProcessingHandler    called from willCapturePhotoFor if capture has taken more than a second
/// - completionHandler         called from didFinishCaptureFor with true for success and false for failure
///
/// ## Reference
/// [AVCapturePhotoCaptureDelegate](https://developer.apple.com/documentation/avfoundation/avcapturephotocapturedelegate)
///
/// ## Implemented delegate methods
///
/// - photoOutput:willBeginCaptureFor:            capture has resolved settings and will soon begin photo capture
/// - photoOutput:willCapturePhotoFor:            photo capture is about to occur.
/// - photoOutput:didFinishProcessingPhoto:error: provides the captured image and associated metadata
/// - photoOutput:didFinishCaptureFor:error:      the capture process is complete.
///
class PhotoCaptureProcessor: NSObject {
    lazy var context = CIContext()

    private(set) var requestedPhotoSettings: AVCapturePhotoSettings
    private let willCapturePhotoAnimation: () -> Void
    private let completionHandler: (PhotoCaptureProcessor) -> Void
    private let photoProcessingHandler: (Bool) -> Void

    // The actual captured photo's data
    var photoData: Data?

    // The maximum time lapse before telling UI to show a spinner
    private var maxPhotoProcessingTime: CMTime?

    // Init takes multiple closures to be called in each step of the photo capture process
    init(with requestedPhotoSettings: AVCapturePhotoSettings,
         willCapturePhotoAnimation: @escaping () -> Void,
         completionHandler: @escaping (PhotoCaptureProcessor) -> Void,
         photoProcessingHandler: @escaping (Bool) -> Void)
    {
        self.requestedPhotoSettings = requestedPhotoSettings
        self.willCapturePhotoAnimation = willCapturePhotoAnimation
        self.completionHandler = completionHandler
        self.photoProcessingHandler = photoProcessingHandler
    }
}

/// This extension adopts AVCapturePhotoCaptureDelegate protocol methods.
extension PhotoCaptureProcessor: AVCapturePhotoCaptureDelegate {
    /// photoOutput:willBeginCaptureFor
    func photoOutput(_: AVCapturePhotoOutput, willBeginCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        maxPhotoProcessingTime =
            resolvedSettings.photoProcessingTimeRange.start +
            resolvedSettings.photoProcessingTimeRange.duration
    }

    /// photoOutput:willCapturePhotoFor
    func photoOutput(_: AVCapturePhotoOutput, willCapturePhotoFor _: AVCaptureResolvedPhotoSettings) {
        DispatchQueue.main.async {
            self.willCapturePhotoAnimation()
        }

        guard let maxPhotoProcessingTime = maxPhotoProcessingTime else { return }

        // Show a spinner if processing time exceeds one second.
        let oneSecond = CMTime(seconds: 2, preferredTimescale: 1)
        if maxPhotoProcessingTime > oneSecond {
            DispatchQueue.main.async {
                self.photoProcessingHandler(true)
            }
        }
    }

    /// photoOutput:didFinishProcessingPhoto:error:
    func photoOutput(_: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        DispatchQueue.main.async {
            self.photoProcessingHandler(false)
        }
        if let error = error {
            print("Error capturing photo: \(error)")
        } else {
            photoData = photo.fileDataRepresentation()
        }
    }

    /// photoOutput:didFinishCaptureFor:error:
    func photoOutput(_: AVCapturePhotoOutput, didFinishCaptureFor _: AVCaptureResolvedPhotoSettings, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error)")
        }
        DispatchQueue.main.async {
            self.completionHandler(self)
        }
    }
}
