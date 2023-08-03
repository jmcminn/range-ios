import AVFoundation
import Combine
import Foundation
import OSLog
import UIKit

/**
 *  Class responsible for managing an AVCaptureSession
 *
 *  Call `configure` and 'start' when the view appears; 'capturePhoto' and 'zoom' with the view open and
 *  'stop' when the view closes
 *
 *  Managing the cameras/audio/video is hard, with a lot of different pieces, most of which are asynchronous and
 *  must be dispatched to other threads to avoid waiting on the main thread.
 *
 *  However, actually drawing the camera preview into a UIView has to be done on the main thread.
 *  #Reference
 *  [AVCam: Building a Camera App](https://developer.apple.com/documentation/avfoundation/cameras_and_media_capture/avcam_building_a_camera_app)
 */
class CameraService: ObservableObject {
    typealias CompletionFunction = (Data?) -> Void
    typealias SetupResultCallbackFunction = (SessionSetupResult) -> Void

    enum SessionSetupResult: String {
        case notConfigured
        case success
        case configurationFailed
    }

    // possible errors when configuring an AVCaptureDevice
    private enum ConfigurationError: Error {
        case videoUnavailable(message: String = "Default video is unavailable")
        case couldntAddVideo(message: String = "Couldn't add video device to session")
        case couldntAddOutput(message: String = "Could not add photo output to the session")
    }

    // isProcessingPhoto is a technical detail of the capture process which runs on the sessionQueue
    // while canCapturePhoto runs on the main queue
    @Published var isProcessingPhoto = false // the camera is currently capturing
    @Published var canCapturePhoto = false // can we enable the UI's camera button?
    @Published var currentZoomFactor = 1.0
    @Published var willCapturePhoto = false
    @Published var hasFlash = false

    let session = AVCaptureSession()
    /// For ultra wide cameras the zoom factors should be divided by 2.0 when presented in UI.
    /// The ultra wide camera has zoom starting from 1.0 but iOS Camera app presents this zoom level as 0.5 in the UI and we want to
    /// keep this behavior, so if ultra wide camera is used this parameter will be 0.5
    var zoomFactorUIMultiplier = 1.0
    var minZoomFactor = 1.0
    var maxZoomFactor = 10.0
    /// zoom factors to be presented in UI so user can tap to zoom to given level. This are device values (not UI, so not multiplied by zoomFactorUIMultiplier)
    var zoomFactors: [Double] = [1.0]
    var isSessionRunning = false
    private var setupResult: SessionSetupResult = .notConfigured
    // Communicate with the session and other session objects on this queue.
    private let sessionQueue = DispatchQueue(label: "session queue")

    @objc dynamic var videoDeviceInput: AVCaptureDeviceInput!

    private let photoOutput = AVCapturePhotoOutput()
    private var inProgressPhotoCaptureDelegates = [Int64: PhotoCaptureProcessor]()

    // -----------------------------------------------------------------------------------------------------------------
    // Configure
    //
    // TODO: add more camera session error handling from
    // https://developer.apple.com/documentation/avfoundation/cameras_and_media_capture/avcam_building_a_camera_app
    // -----------------------------------------------------------------------------------------------------------------

    /// The setupResultCallback is called on the main queue once determined
    func configure(setupResultCallback: @escaping SetupResultCallbackFunction) {
        #if targetEnvironment(simulator)
            // don't configure on simulator...
            canCapturePhoto = true
            hasFlash = true
            zoomFactors = [1, 2, 3]
        #else

            /*
             Setup the capture session.
             In general, it's not safe to mutate an AVCaptureSession or any of its
             inputs, outputs, or connections from multiple threads at the same time.

             Don't perform these tasks on the main queue because
             AVCaptureSession.startRunning() is a blocking call, which can
             take a long time. Dispatch session setup to the sessionQueue, so
             that the main queue isn't blocked, which keeps the UI responsive.
             */
            sessionQueue.async {
                self._configure()
                DispatchQueue.main.async {
                    setupResultCallback(self.setupResult)
                }
            }
        #endif
    }

    // Try to select a camera by asking AVCapture if it can use various cameras on the device
    private func _selectACaptureDevice() throws -> AVCaptureDevice {
        if let d = AVCaptureDevice.default(.builtInTripleCamera, for: .video, position: .back) { return d }
        if let d = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) { return d }
        if let d = AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back) { return d }
        if let d = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) { return d }
        throw ConfigurationError.videoUnavailable()
    }

    // To be called on the sessionQueue
    private func _configure() {
        do {
            session.beginConfiguration()
            defer {
                session.commitConfiguration()
            }

            session.sessionPreset = .photo

            // to print the camera info
            // AVCaptureDevice._printDeviceInfo()

            // find some video input
            let videoDevice = try _selectACaptureDevice()
            zoomFactors = videoDevice._getZoomFactors()

            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)

            // Add video input.
            guard session.canAddInput(videoDeviceInput) else { throw ConfigurationError.couldntAddVideo() }
            session.addInput(videoDeviceInput)
            self.videoDeviceInput = videoDeviceInput

            // Special zoom handling for ultra wide camera, see docs of `zoomFactorUIMultiplier`
            if videoDevice._hasUltraWideCamera {
                zoomFactorUIMultiplier = 0.5

                // start with zoom 2 (which is 1.0 in the UI) - we want to start with wide, not ultra wide
                set(zoom: 2.0, animated: false)
            }

            // Add the photo output.
            guard session.canAddOutput(photoOutput) else { throw ConfigurationError.couldntAddOutput() }
            session.addOutput(photoOutput)

            // configure the output
            photoOutput.isHighResolutionCaptureEnabled = true
            photoOutput.maxPhotoQualityPrioritization = .quality
            DispatchQueue.main.async {
                self.maxZoomFactor = min(10.0, videoDeviceInput.device.activeFormat.videoMaxZoomFactor)
                self.hasFlash = videoDeviceInput.device.hasFlash
            }
            setupResult = .success
        } catch let ConfigurationError.videoUnavailable(message),
                    let ConfigurationError.couldntAddVideo(message),
                    let ConfigurationError.couldntAddOutput(message)
        {
            Logger.camera.error("device configuration failed: \(message, privacy: .public)")
            setupResult = .configurationFailed
        } catch {
            Logger.camera.error("device creation failed: \(error.localizedDescription, privacy: .public)")
            setupResult = .configurationFailed
        }
    }

    // -----------------------------------------------------------------------------------------------------------------
    // Start/Stop camera session
    // -----------------------------------------------------------------------------------------------------------------

    // start the camera capture session and set isSessionRunning and canCapturePhoto
    func start() {
        sessionQueue.async {
            guard self.setupResult == .success else {
                Logger.camera.error("configuration problem: \(String(describing: self.setupResult))")
                return
            }
            guard !self.isSessionRunning else {
                Logger.camera.error("session already started: \(String(describing: self.setupResult))")
                return
            }

            self.session.startRunning()
            self.isSessionRunning = self.session.isRunning

            DispatchQueue.main.async {
                self.canCapturePhoto = true
            }
        }
    }

    // stop the camera capture session and reset isSessionRunning and canCapturePhoto
    func stop() {
        sessionQueue.async {
            guard self.isSessionRunning else { return }
            guard self.setupResult == .success else { return }

            self.session.stopRunning()
            self.isSessionRunning = self.session.isRunning

            DispatchQueue.main.async {
                self.canCapturePhoto = false
            }
        }
    }

    // -----------------------------------------------------------------------------------------------------------------
    // Focus the camera
    // -----------------------------------------------------------------------------------------------------------------
    func focus(onCaptureDevicePoint focusPoint: CGPoint) {
        let device = videoDeviceInput.device
        do {
            defer {
                device.unlockForConfiguration()
            }
            try device.lockForConfiguration()
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = focusPoint
                device.focusMode = .autoFocus
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = focusPoint
                device.exposureMode = .autoExpose
            }
        } catch {
            Logger.camera.error("focus failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // -----------------------------------------------------------------------------------------------------------------
    // Zoom the camera
    // -----------------------------------------------------------------------------------------------------------------

    // change the zoom on the camera
    func set(zoom: CGFloat, animated: Bool) {
        let newZoom = max(minZoomFactor, min(zoom, maxZoomFactor))
        DispatchQueue.main.async {
            self.currentZoomFactor = newZoom
        }
        let device = videoDeviceInput.device

        do {
            try device.lockForConfiguration()
            if animated {
                device.ramp(toVideoZoomFactor: newZoom, withRate: 10)
            } else {
                device.videoZoomFactor = newZoom
            }
            device.unlockForConfiguration()
        } catch {
            Logger.camera.error("setZoom failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // -----------------------------------------------------------------------------------------------------------------
    // Capture a photo
    // -----------------------------------------------------------------------------------------------------------------

    // Top level function: capture a photo and pass the result to the completion function -- while also providing
    // visual feedback in the form of "snapping" the picture and showing a spinner while iOS processes the photo
    func capturePhoto(
        flashMode: AVCaptureDevice.FlashMode,
        deviceOrientation: UIDeviceOrientation,
        completion: @escaping CompletionFunction
    ) {
        #if targetEnvironment(simulator)
            _captureDummyPhotoForTesting(completion: completion)
        #else
            guard setupResult != .configurationFailed else { return }

            // we're currently taking a photo: disable the camera button until we're done
            canCapturePhoto = false

            let orientation = AVCaptureVideoOrientation(deviceOrientation: deviceOrientation) ?? .portrait

            sessionQueue.async {
                self._capturePhoto(flashMode: flashMode, videoOrientation: orientation, completion: completion)
            }
        #endif
    }

    // If there's no camera in the simulator, just call completion on a hard-coded photo
    private func _captureDummyPhotoForTesting(completion: @escaping CompletionFunction) {
        // hardcoded photo for simulator
        DispatchQueue.main.async {
            guard let sampleImageURL = Bundle.main.url(
                forResource: UIDevice.current.orientation
                    .isPortrait ? "sample_photo_portrait" : "sample_photo_landscape",
                withExtension: "jpg"
            ) else { return }

            do {
                let imageData = try Data(contentsOf: sampleImageURL)
                completion(imageData)
            } catch {
                Logger.assets.error("Couldn't load the \(sampleImageURL, privacy: .public) image from bundle")
            }
        }
    }

    // The real core of photo capture is here, which in addition to telling iOS to take the picture also
    // updates the UI to give the user feedback while the photo is being captured
    // (a flash when the user presses the camera and a spinner while the photo is being processed before it's done)
    // To be called on the sessionQueue
    private func _capturePhoto(
        flashMode: AVCaptureDevice.FlashMode,
        videoOrientation: AVCaptureVideoOrientation,
        completion: @escaping CompletionFunction
    ) {
        if let photoOutputConnection = photoOutput.connection(with: .video) {
            photoOutputConnection.videoOrientation = videoOrientation
        }

        let photoSettings = _initializePhotoSettings(flashMode: flashMode)

        // closure: the photo is about to be captured
        let flashScreenToIndicatePhotoIsAboutToBeTaken = { [weak self] in
            // Tells the UI to flash the screen to signal that SwiftCamera took a photo.
            self?.willCapturePhoto = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.willCapturePhoto = false
            }
        }

        // closure: we're done, we can now call the completion handler we were passed in capturePhoto
        let makeCallbackAndCleanUp: (PhotoCaptureProcessor) -> Void = { [weak self] photoCaptureProcessor in
            guard let self = self else { return }

            // When the capture is complete, remove a reference to the photo capture delegate so it can be deallocated.

            // TODO: this is where we would resize the photo if we don't want the "high-res" 4032
            let resizedPhotoData = resizeImage(imageData: photoCaptureProcessor.photoData, maxResolution: 4032)
            completion(resizedPhotoData)
            self.canCapturePhoto = true

            self.sessionQueue.async {
                // remove the strong copy of the weak reference we created earlier
                self.inProgressPhotoCaptureDelegates[photoCaptureProcessor.requestedPhotoSettings.uniqueID] = nil
            }
        }

        // closure: iOS is processing; show a spinner
        let showSpinnerWhilePhotoIsBeingProcessed: (Bool) -> Void = { [weak self] isProcessing in
            // Animates a spinner while photo is processing
            self?.isProcessingPhoto = isProcessing
        }

        // aggregate the behavior we need for the photo capture; this is delegate of the iOS capturePhoto function
        let photoCaptureProcessor = PhotoCaptureProcessor(
            with: photoSettings,
            willCapturePhotoAnimation: flashScreenToIndicatePhotoIsAboutToBeTaken,
            completionHandler: makeCallbackAndCleanUp,
            photoProcessingHandler: showSpinnerWhilePhotoIsBeingProcessed
        )

        // The photo output holds a weak reference to the photo capture delegate and
        // stores it in an array to maintain a strong reference.
        inProgressPhotoCaptureDelegates[photoCaptureProcessor.requestedPhotoSettings.uniqueID] = photoCaptureProcessor

        // Take the photo!
        photoOutput.capturePhoto(with: photoSettings, delegate: photoCaptureProcessor)
    }

    // define photo-capture settings. Prefer: HEIF, auto flash mode, high resolution, quality priority, preview format
    private func _initializePhotoSettings(flashMode: AVCaptureDevice.FlashMode) -> AVCapturePhotoSettings {
        // Capture JPEG photos when supported. Enable according to user settings and high-resolution photos.
        let photoSettings: AVCapturePhotoSettings
        if photoOutput.availablePhotoCodecTypes.contains(.jpeg) {
            photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg,
                                                            AVVideoCompressionPropertiesKey: [AVVideoQualityKey: 0.75]])
        } else {
            // TODO: is there a case where jpeg is not supported?
            photoSettings = AVCapturePhotoSettings()
            Logger.camera.error("available photo codec types has no jpeg")
        }

        // Sets the flash option for this capture.
        if videoDeviceInput.device.hasFlash, videoDeviceInput.device.isFlashAvailable {
            photoSettings.flashMode = flashMode
        }

        photoSettings.isHighResolutionPhotoEnabled = true

        // Sets the preview thumbnail pixel format
        if !photoSettings.__availablePreviewPhotoPixelFormatTypes.isEmpty {
            photoSettings
                .previewPhotoFormat =
                [kCVPixelBufferPixelFormatTypeKey as String: photoSettings
                    .__availablePreviewPhotoPixelFormatTypes.first!]
        }

        photoSettings.photoQualityPrioritization = .quality
        return photoSettings
    }
}

extension AVCaptureDevice {
    /// Returns if this device is an ultra wide camera or is a virtual device that has an ultra wide camera constituent
    var _hasUltraWideCamera: Bool {
        deviceType == .builtInUltraWideCamera || constituentDevices
            .contains { $0.deviceType == .builtInUltraWideCamera }
    }

    /// Return zoom factors for this device. This are selected zoom levels important for this device (mainly the levels at which
    /// the device switches the camera but also the secondary zoom factors)
    /// This array always contains the 1 zoom factor.
    /// The factors are to be used in UI - for each zoom factor there's a button to reset to given zoom (to replicated the iOS Camera app)
    /// The factors are doubles but are rounded up. iPhone X reports videoZoomFactors = [1.799999952316284]
    /// but in iOS Camera app they label it as zoom level 2, so they do some scaling of the zoom range... We don't do that and cheat a little
    /// bit, so 1.79 will be rounded up to 2 and we'll use that as the zoom factor
    func _getZoomFactors() -> [Double] {
        var factors = [Double]()
        factors.append(1.0)
        factors.append(contentsOf: virtualDeviceSwitchOverVideoZoomFactors.map { factor in
            Double(truncating: factor).rounded(.up)
        })
        if #available(iOS 16.0, *) {
            factors.append(contentsOf: activeFormat.secondaryNativeResolutionZoomFactors.map { factor in
                Double(factor.rounded(.up))
            })
        }
        return factors.uniqued().sorted()
    }

    /// print the info about cameras and their supported zoom factors and secondary native resolution zoom factors
    static func _printDeviceInfo() {
        let deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInUltraWideCamera, .builtInWideAngleCamera, .builtInTelephotoCamera,
            .builtInDualWideCamera, .builtInDualCamera,
            .builtInTripleCamera,
        ]

        for deviceType in deviceTypes {
            if let d = AVCaptureDevice.default(deviceType, for: .video, position: .back) {
                print("type: ", deviceType.rawValue, d)
                print("constituent: ", d.constituentDevices)
                print("videoZoomFactors ", d.virtualDeviceSwitchOverVideoZoomFactors)
                if #available(iOS 16.0, *) {
                    print("secondaryNativeResolutionZoomFactors ",
                          d.activeFormat.secondaryNativeResolutionZoomFactors)
                }
            }
        }
    }
}

extension AVCaptureVideoOrientation {
    init?(deviceOrientation: UIDeviceOrientation) {
        switch deviceOrientation {
        case .portrait: self = .portrait
        case .portraitUpsideDown: self = .portraitUpsideDown
        case .landscapeLeft: self = .landscapeRight
        case .landscapeRight: self = .landscapeLeft
        default: return nil
        }
    }
}
