import Foundation
import Combine
import AVFoundation
import UIKit

/**
 Class responsible for handling the AVCaptureSession
 
 It requires calling `configure` and then `start`
 */
class CameraService: ObservableObject {
    
    enum SessionSetupResult {
        case notConfigured
        case success
        case configurationFailed
    }
    
    @Published var canCapturePhoto = false
    @Published var currentZoomFactor = 1.0
    @Published var willCapturePhoto = false
    @Published var isProcessingPhoto = false
    
    let session = AVCaptureSession()
    var minZoomFactor = 1.0
    var maxZoomFactor = 10.0
    var isSessionRunning = false
    private var setupResult: SessionSetupResult = .notConfigured
    // Communicate with the session and other session objects on this queue.
    private let sessionQueue = DispatchQueue(label: "session queue")
    
    @objc dynamic var videoDeviceInput: AVCaptureDeviceInput!
    
    private let photoOutput = AVCapturePhotoOutput()
    private var inProgressPhotoCaptureDelegates = [Int64: PhotoCaptureProcessor]()
    
    // TODO: add more camera session error handling from
    // https://developer.apple.com/documentation/avfoundation/cameras_and_media_capture/avcam_building_a_camera_app
    
    /// The setupResultCallback is called on the main queue once determined
    func configure(setupResultCallback: @escaping (SessionSetupResult) -> Void) {
#if targetEnvironment(simulator)
        // don't configure on simulator...
        canCapturePhoto = true
        return
#endif
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
            self.configureSession()
            DispatchQueue.main.async {
                setupResultCallback(self.setupResult)
            }
        }
    }
    
    // Call this on the session queue.
    private func configureSession() {
        
        session.beginConfiguration()
        
        session.sessionPreset = .photo
        
        // Add video input.
        do {
            var device: AVCaptureDevice?
            let deviceTypesToCheck: [AVCaptureDevice.DeviceType] = [.builtInTripleCamera, .builtInDualCamera, .builtInDualWideCamera, .builtInWideAngleCamera]
            for deviceType in deviceTypesToCheck {
                if let d = AVCaptureDevice.default(deviceType, for: .video, position: .back) {
                    device = d
                    break
                }
            }
            
            guard let videoDevice = device else {
                // TODO: log this detailed message
                print("Default video device is unavailable.")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
            
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
                
            } else {
                print("Couldn't add video device input to the session.")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
        } catch {
            print("Couldn't create video device input: \(error)")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        
        // Add the photo output.
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            
            photoOutput.isHighResolutionCaptureEnabled = true
            photoOutput.maxPhotoQualityPrioritization = .quality
            
        } else {
            print("Could not add photo output to the session")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        
        maxZoomFactor = min(10.0, self.videoDeviceInput.device.activeFormat.videoMaxZoomFactor)
        
        session.commitConfiguration()
        
        setupResult = .success
    }
    
    func start() {
        sessionQueue.async {
            guard self.setupResult == .success else {
                print("configuration problem: \(self.setupResult)")
                return
            }
            guard !self.isSessionRunning else {
                print("session already started")
                return
            }
            self.session.startRunning()
            self.isSessionRunning = self.session.isRunning
            DispatchQueue.main.async {
                self.canCapturePhoto = true
            }
        }
    }
    
    func stop(completion: (() -> ())? = nil) {
        sessionQueue.async {
            if self.isSessionRunning {
                if self.setupResult == .success {
                    self.session.stopRunning()
                    self.isSessionRunning = self.session.isRunning
                    DispatchQueue.main.async {
                        self.canCapturePhoto = false
                    }
                }
            }
        }
    }
    
    func set(zoom: CGFloat) {
        currentZoomFactor = max(minZoomFactor, min(zoom, maxZoomFactor))
        let device = self.videoDeviceInput.device
        
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = currentZoomFactor
            device.unlockForConfiguration()
        }
        catch {
            print(error.localizedDescription)
        }
    }
    
    public func capturePhoto(completion: @escaping (Data?) -> Void) {
#if targetEnvironment(simulator)
        // hardcoded photo for simulator
        DispatchQueue.main.async {
            guard let sampleImageURL = Bundle.main.url(forResource: "Rectangle 515", withExtension: "png") else { return }
            do {
                let imageData = try Data(contentsOf: sampleImageURL)
                completion(imageData)
            } catch {
                print("Couldn't load \(sampleImageURL)")
            }
        }
        return
#endif
        if self.setupResult != .configurationFailed {
            self.canCapturePhoto = false
            
            let videoOrientation = AVCaptureVideoOrientation(deviceOrientation: UIDevice.current.orientation) ?? .portrait
            
            sessionQueue.async {
                if let photoOutputConnection = self.photoOutput.connection(with: .video) {
                    photoOutputConnection.videoOrientation = videoOrientation
                }
                var photoSettings = AVCapturePhotoSettings()
                
                // Capture HEIF photos when supported. Enable according to user settings and high-resolution photos.
                if  self.photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                    photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
                }
                
                // Sets the flash option for this capture.
                if self.videoDeviceInput.device.isFlashAvailable {
                    // TODO: implement flashmode
                    photoSettings.flashMode = .auto
                }
                
                photoSettings.isHighResolutionPhotoEnabled = true
                
                // Sets the preview thumbnail pixel format
                if !photoSettings.__availablePreviewPhotoPixelFormatTypes.isEmpty {
                    photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: photoSettings.__availablePreviewPhotoPixelFormatTypes.first!]
                }
                
                photoSettings.photoQualityPrioritization = .quality
                
                let photoCaptureProcessor = PhotoCaptureProcessor(with: photoSettings, willCapturePhotoAnimation: { [weak self] in
                    // Tells the UI to flash the screen to signal that SwiftCamera took a photo.
                    DispatchQueue.main.async {
                        self?.willCapturePhoto = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self?.willCapturePhoto = false
                    }
                    
                }, completionHandler: { [weak self] (photoCaptureProcessor) in
                    // When the capture is complete, remove a reference to the photo capture delegate so it can be deallocated.
                    DispatchQueue.main.async {
                        completion(photoCaptureProcessor.photoData)
                        self?.canCapturePhoto = true
                    }
                    
                    self?.sessionQueue.async {
                        self?.inProgressPhotoCaptureDelegates[photoCaptureProcessor.requestedPhotoSettings.uniqueID] = nil
                    }
                }, photoProcessingHandler: { [weak self] animate in
                    // Animates a spinner while photo is processing
                    DispatchQueue.main.async {
                        if animate {
                            self?.isProcessingPhoto = true
                        } else {
                            self?.isProcessingPhoto = false
                        }
                    }
                })
                
                // The photo output holds a weak reference to the photo capture delegate and stores it in an array to maintain a strong reference.
                self.inProgressPhotoCaptureDelegates[photoCaptureProcessor.requestedPhotoSettings.uniqueID] = photoCaptureProcessor
                self.photoOutput.capturePhoto(with: photoSettings, delegate: photoCaptureProcessor)
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
