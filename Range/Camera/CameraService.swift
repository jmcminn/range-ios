import Foundation
import Combine
import AVFoundation
import UIKit

/**
 Class responsible for handling the AVCaptureSession
 
 It requires calling `configure` and then `start`
 */
class CameraService {
    
    enum SessionSetupResult {
        case notConfigured
        case success
        case configurationFailed
    }
    
    public let session = AVCaptureSession()
    var isSessionRunning = false
    private var setupResult: SessionSetupResult = .notConfigured
    // Communicate with the session and other session objects on this queue.
    private let sessionQueue = DispatchQueue(label: "session queue")
    
    @objc dynamic var videoDeviceInput: AVCaptureDeviceInput!
    
    private let photoOutput = AVCapturePhotoOutput()
    
    // TODO: add more camera session error handling from
    // https://developer.apple.com/documentation/avfoundation/cameras_and_media_capture/avcam_building_a_camera_app
    
    /// The setupResultCallback is called on the main queue once determined
    func configure(setupResultCallback: @escaping (SessionSetupResult) -> Void) {
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
        }
    }
    
    func stop(completion: (() -> ())? = nil) {
        sessionQueue.async {
            if self.isSessionRunning {
                if self.setupResult == .success {
                    self.session.stopRunning()
                    self.isSessionRunning = self.session.isRunning
                }
            }
        }
    }
}
