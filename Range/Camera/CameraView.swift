import AVFoundation
import Combine
import SwiftUI

// Helper to convert a CameraService's currentZoomFactor to a string for display on top of the photo preview
class CameraViewModel: ObservableObject {
    let service: CameraService

    // translate the CameraService.currentZoomFactor to a string to be displayed in the view
    @Published var zoomString = ""

    private var subscriptions = Set<AnyCancellable>()

    init(service: CameraService) {
        self.service = service

        // update zoomString when the @Published CameraService.$currentZoomFactor changes
        let updateZoomString: (Double) -> Void = { [weak self] zoom in
            guard let self = self else { return }
            let zoomInt = Int(zoom)
            let zoomDecimal: Int = .init(10 * (zoom - Double(zoomInt)))
            if zoomDecimal == 0 {
                self.zoomString = "\(zoomInt)x"
            } else {
                self.zoomString = "\(zoomInt),\(zoomDecimal)x"
            }
        }

        // add a listener for changes to service.$currentZoomFactor and hold a strong reference to it
        service.$currentZoomFactor.sink(receiveValue: updateZoomString).store(in: &subscriptions)
    }
}

/// # CameraView
///
/// The main camera view with a pinch-zoomable photo preview and buttons to take a photo or cancel
struct CameraView: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass

    @ObservedObject var cameraService: CameraService
    @ObservedObject var model: CameraViewModel
    var closeAction: () -> Void
    var takePhotoAction: () -> Void

    /// The CameraService state (canCapturePhoto, willCapturePhoto, isProcessingPhoto) directly
    /// affects the view and the CameraService.session is used for the photo preview. In the other
    /// direction, zooming in the CameraView set the zoom of the CameraService
    ///
    /// - Parameters:
    ///   - cameraService: manages the current state of the photo capture
    ///   - closeAction: the user pushed the close button
    ///   - takePhotoAction: the user pushed the takePhoto button
    init(
        cameraService: CameraService,
        closeAction: @escaping () -> Void,
        takePhotoAction: @escaping () -> Void
    ) {
        self.cameraService = cameraService
        self.closeAction = closeAction
        self.takePhotoAction = takePhotoAction
        model = CameraViewModel(service: cameraService)
    }

    // the current scale not affected by the MagnificationGesture in progress
    @State var cameraScale: CGFloat = 1.0
    // progress of the current MagnificationGesture
    @State var progressingScale: CGFloat = 1.0

    var closeButton: some View {
        Button(action: closeAction) {
            Circle()
                .strokeBorder(Color.Red_04, lineWidth: 2)
                .background(Circle().fill(Color.Red_03))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "xmark")
                        .foregroundColor(Color.Neutral_01)
                )
        }.buttonStyle(.plain)
    }

    struct TakePhotoButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .foregroundColor(Color.Neutral_01)
                .scaleEffect(configuration.isPressed ? 0.9 : 1)
                .animation(.easeInOut(duration: 0.05), value: configuration.isPressed)
        }
    }

    // Circular button inside a larger circular ring
    var takePhotoButton: some View {
        ZStack {
            Circle()
                .strokeBorder(Color.Neutral_01, lineWidth: 4)
                .foregroundColor(.clear)
                .frame(width: 66, height: 66, alignment: .center)
            Button(action: takePhotoAction) {
                Circle()
                    .frame(width: 54, height: 54, alignment: .center)
            }
            .buttonStyle(TakePhotoButtonStyle())
            .disabled(!cameraService.canCapturePhoto)
        }
    }

    // Text overlay on photo preview showing the current zoom level
    var zoomView: some View {
        Text(model.zoomString)
            .font(.system(size: 11)).fontWeight(.semibold)
            .foregroundColor(Color.Neutral_01)
            .frame(width: 30, height: 30)
            .background(Circle().fill(Color.Neutral_10.opacity(0.8)))
    }

    // Grid overlay on photo preview showing a grid
    var gridView: some View {
        GeometryReader { cameraFrame in
            Path { path in
                let w = cameraFrame.size.width
                let h = cameraFrame.size.height
                path.move(to: CGPoint(x: w / 3, y: 0))
                path.addLine(to: CGPoint(x: w / 3, y: h))
                path.closeSubpath()
                path.move(to: CGPoint(x: w * 2 / 3, y: 0))
                path.addLine(to: CGPoint(x: w * 2 / 3, y: h))
                path.closeSubpath()
                path.move(to: CGPoint(x: 0, y: h / 3))
                path.addLine(to: CGPoint(x: w, y: h / 3))
                path.closeSubpath()
                path.move(to: CGPoint(x: 0, y: h * 2 / 3))
                path.addLine(to: CGPoint(x: w, y: h * 2 / 3))
                path.closeSubpath()
            }
            .stroke(Color.Neutral_01.opacity(0.5), lineWidth: 1)
        }
    }

    // Photo preview from the CameraService
    private func cameraView(reader: GeometryProxy) -> some View {
        CameraPreview(session: cameraService.session)
            .frame(height: reader.size.width * 4.0 / 3.0)
            .gesture(
                MagnificationGesture()
                    .onChanged {
                        progressingScale = $0
                        cameraService.set(zoom: cameraScale * progressingScale)
                    }
                    .onEnded { _ in
                        cameraScale = cameraService.currentZoomFactor
                        progressingScale = 1
                    }
            )
            .overlay(
                gridView
            )
            .overlay(
                Group {
                    if cameraService.willCapturePhoto {
                        Color.black
                    }
                }
                .animation(
                    .easeInOut(duration: 0.1),
                    value: cameraService.willCapturePhoto
                )
            )
            .overlay {
                if cameraService.isProcessingPhoto {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color
                                .Neutral_01))
                }
            }
    }

    // main view
    var body: some View {
        GeometryReader { reader in
            if horizontalSizeClass == .regular, verticalSizeClass == .regular {
                // "iPad" draft layout (present controls on top of the camera view)
                ZStack {
                    Color.Neutral_10.edgesIgnoringSafeArea(.all)
                    Spacer()
                    ZStack(alignment: .bottom) {
                        cameraView(reader: reader)
                        VStack {
                            zoomView
                            ZStack {
                                HStack {
                                    closeButton
                                        .padding(20)
                                    Spacer()
                                }
                                HStack {
                                    takePhotoButton
                                        .padding(16)
                                }
                            }
                        }.padding(.bottom, 22)
                    }
                    Spacer()
                }

            } else {
                ZStack {
                    Color.Neutral_10.edgesIgnoringSafeArea(.all)
                    VStack {
                        Spacer()
                        ZStack(alignment: .bottom) {
                            cameraView(reader: reader)
                            zoomView.padding(.bottom, 22)
                        }
                        Spacer()
                        ZStack {
                            HStack {
                                closeButton
                                    .padding(20)
                                Spacer()
                            }
                            HStack {
                                takePhotoButton
                                    .padding(16)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CameraView(cameraService: CameraService(), closeAction: {}, takePhotoAction: {})
        }
    }
}
