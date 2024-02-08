import AVFoundation
import Combine
import SwiftUI

/// Wrapper to show VideoPreviewView in SwiftUI
struct CameraPreview: UIViewRepresentable {
    /// UIView with AVCaptureVideoPreviewLayer layer
    class VideoPreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            guard let layer = layer as? AVCaptureVideoPreviewLayer else {
                fatalError(
                    "Expected `AVCaptureVideoPreviewLayer` type for layer. Check CameraPreview.layerClass implementation."
                )
            }
            return layer
        }
    }

    let view = VideoPreviewView()
    let cameraService: CameraService

    /// callback reporting taps. The first parameter is the point in the CameraPreview coordinates and the 2nd is converted to capture device point
    let tappedCallback: (CGPoint, CGPoint) -> Void

    func makeUIView(context _: UIViewRepresentableContext<CameraPreview>) -> VideoPreviewView {
        view.videoPreviewLayer.cornerRadius = 32
        view.videoPreviewLayer.connection?.videoOrientation = .portrait
        return view
    }

    func makeCoordinator() -> CameraPreview.Coordinator {
        // create coordinator with a tap callback that uses the wrapped view.videoPreviewLayer to
        // translate the gesture recognizer tap point to capture device point and report both
        // coordinates to tappedCallback registered for CameraPreview
        Coordinator(cameraService: cameraService, videoPreviewView: view) { point in
            tappedCallback(point, view.videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: point))
        }
    }

    // based on: https://stackoverflow.com/a/56518293
    /// Coordinator added to CameraPreview to add tap callback
    class Coordinator: NSObject {
        let cameraService: CameraService
        let videoPreviewView: VideoPreviewView
        var tappedCallback: (CGPoint) -> Void
        /// combine observers
        private var subscriptions = Set<AnyCancellable>()
        init(
            cameraService: CameraService,
            videoPreviewView: VideoPreviewView,
            tappedCallback: @escaping ((CGPoint) -> Void)
        ) {
            self.cameraService = cameraService
            self.videoPreviewView = videoPreviewView
            self.tappedCallback = tappedCallback
            super.init()
            // gesture recognizer requires the action to be @objc function but UIViewRepresentable can
            // only be a struct (so no objc support). So we need to add a custom coordinator that will
            // called on tap
            videoPreviewView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
            cameraService.$isSessionRunning
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    guard let self else { return }
                    if self.cameraService.isSessionRunning, self.videoPreviewView.videoPreviewLayer.session == nil {
                        self.videoPreviewView.videoPreviewLayer.session = cameraService.session
                    }
                }.store(in: &subscriptions)
        }

        @objc func tapped(gesture: UITapGestureRecognizer) {
            let point = gesture.location(in: gesture.view)
            tappedCallback(point)
        }
    }

    func updateUIView(_: VideoPreviewView, context _: Context) {}
}

struct CameraPreview_Previews: PreviewProvider {
    static var previews: some View {
        CameraPreview(cameraService: CameraService(), tappedCallback: { _, _ in })
            .frame(height: 300)
    }
}
