import AVFoundation
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
    let session: AVCaptureSession
    /// callback reporting taps. The first parameter is the point in the CameraPreview coordinates and the 2nd is converted to capture device point
    let tappedCallback: (CGPoint, CGPoint) -> Void

    func makeUIView(context: UIViewRepresentableContext<CameraPreview>) -> VideoPreviewView {
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.cornerRadius = 32
        view.videoPreviewLayer.connection?.videoOrientation = .portrait

        // gesture recognizer requires the action to be @objc function but UIViewRepresentable can
        // only be a struct (so no objc support). So we need to add a custom coordinator that will
        // called on tap
        view.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator,
                                                         action: #selector(Coordinator.tapped)))

        return view
    }

    func makeCoordinator() -> CameraPreview.Coordinator {
        // create coordinator with a tap callback that uses the wrapped view.videoPreviewLayer to
        // translate the gesture recognizer tap point to capture device point and report both
        // coordinates to tappedCallback registered for CameraPreview
        Coordinator { point in
            tappedCallback(point, view.videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: point))
        }
    }

    // based on: https://stackoverflow.com/a/56518293
    /// Coordinator added to CameraPreview to add tap callback
    class Coordinator: NSObject {
        var tappedCallback: (CGPoint) -> Void
        init(tappedCallback: @escaping ((CGPoint) -> Void)) {
            self.tappedCallback = tappedCallback
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
        CameraPreview(session: AVCaptureSession(), tappedCallback: { _, _ in })
            .frame(height: 300)
    }
}
