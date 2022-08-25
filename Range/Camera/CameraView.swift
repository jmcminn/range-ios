import AVFoundation
import Combine
import SwiftUI

/// # CameraView
///
/// The main camera view with a pinch-zoomable photo preview and buttons to take a photo or cancel
struct CameraView: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass

    /// the angle to use  for UI elements rotation when the device orientation changes
    @State private var uiAngle: Angle = .degrees(0)

    @ObservedObject var model: CameraViewModel
    @ObservedObject var camera: CameraService

    /// The CameraService state (canCapturePhoto, willCapturePhoto, isProcessingPhoto) directly
    /// affects the view and the CameraService.session is used for the photo preview. In the other
    /// direction, zooming in the CameraView set the zoom of the CameraService
    ///
    /// - Parameters:
    ///   - model: manages the state of the camera and callbacks for view controller
    init(model: CameraViewModel) {
        self.model = model
        camera = model.camera
    }

    // the current scale not affected by the MagnificationGesture in progress
    @State var cameraScale: CGFloat = 1.0
    // progress of the current MagnificationGesture
    @State var progressingScale: CGFloat = 1.0

    var closeButton: some View {
        Button(action: model.closeAction ?? {}) {
            Circle()
                .strokeBorder(Color.Neutral_07, lineWidth: 1)
                .background(Circle().fill(Color.Neutral_09))
                .frame(width: 40, height: 40)
                .overlay(Image(systemName: "xmark").font(.title3.bold()).foregroundColor(.Red_03))
        }.buttonStyle(.plain)
    }

//    var flashButton: some View {
//        Button(action: {}) {
//            Circle()
//                .strokeBorder(Color.Neutral_07, lineWidth: 1)
//                .background(Circle().fill(Color.Neutral_09))
//                .frame(width: 40, height: 40)
//                .overlay(Image(systemName: "bolt.fill").font(.body.bold()).foregroundColor(.Neutral_04))
//        }.buttonStyle(.plain)
//            .disabled(true)
//    }

    var cameraRollButton: some View {
        Button(action: {}) {
            Circle()
                .strokeBorder(Color.Neutral_07, lineWidth: 1)
                .background(Circle().fill(Color.Neutral_09))
                .frame(width: 40, height: 40)
                .overlay(Image(systemName: "photo.on.rectangle.angled").font(.body.bold())
                    .foregroundColor(.Neutral_04))
        }.buttonStyle(.plain)
            .disabled(true)
    }

//    var settingsButton: some View {
//        Button(action: {}) {
//            Circle()
//                .strokeBorder(Color.Neutral_07, lineWidth: 1)
//                .background(Circle().fill(Color.Neutral_09))
//                .frame(width: 40, height: 40)
//                .overlay(Image(systemName: "gearshape").font(.body.bold())
//                    .foregroundColor(.Neutral_04))
//        }.buttonStyle(.plain)
//            .disabled(true)
//    }

    var imageButton: some View {
        Button(action: {}) {
            Image(uiImage: model.photoThumbnail ?? UIImage())
                .frame(width: 40, height: 40)
                .scaledToFill()
                .clipped()
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).fill(Color.Neutral_10).opacity(0.2))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.Neutral_07, lineWidth: 1))
                .overlay(Text(String(model.numberOfPhotos)).foregroundColor(Color.Neutral_01)
                    .font(.system(size: 16).bold()))
        }.buttonStyle(.plain)
    }

    var toggleAnnotationsButton: some View {
        Button(action: model.toggleAnnotations) {
            Circle()
                .strokeBorder(model.annotationsEnabled ? Color.Pink_04 : Color.Neutral_07, lineWidth: 2)
                .background(Circle().fill(model.annotationsEnabled ? Color.Pink_03 : Color.Neutral_09))
                .frame(width: 50, height: 50)
                .overlay(Image(systemName: "tag").font(.callout.bold())
                    .foregroundColor(model.multiPhotoEnabled ? .Neutral_01 : .Neutral_04))
        }.buttonStyle(.plain)
    }

    var toggleMultiPhotoButton: some View {
        Button(action: model.toggleMultiPhoto) {
            Circle()
                .strokeBorder(model.multiPhotoEnabled ? Color.Pink_04 : Color.Neutral_07, lineWidth: 2)
                .background(Circle().fill(model.multiPhotoEnabled ? Color.Pink_03 : Color.Neutral_09))
                .frame(width: 50, height: 50)
                .overlay(Image(systemName: "photo.on.rectangle").font(.callout.bold())
                    .foregroundColor(model.multiPhotoEnabled ? .Neutral_01 : .Neutral_04))
        }.buttonStyle(.plain)
    }

    var nextButton: some View {
        Button(action: model.nextAction ?? {}) {
            Circle()
                .strokeBorder(Color.Primary_Blue_06, lineWidth: 2)
                .background(Circle().fill(Color.Primary_Blue_04))
                .frame(width: 50, height: 50)
                .overlay(Image(systemName: "arrow.forward").font(.title3.bold())
                    .foregroundColor(.Neutral_01))
        }.buttonStyle(.plain)
            .disabled(model.numberOfPhotos == 0)
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
            Button(action: model.takePhotoAction ?? {}) {
                Circle()
                    .frame(width: 54, height: 54, alignment: .center)
            }
            .buttonStyle(TakePhotoButtonStyle())
            .disabled(!camera.canCapturePhoto)
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

    /// Banner showing the current model bannerText
    var bannerView: some View {
        Label(model.bannerText!, systemImage: model.bannerIcon!)
            .font(.subheadline.bold())
            .foregroundColor(.Neutral_01)
            .padding(9)
            .background(ZStack {
                RoundedRectangle(cornerRadius: 10).fill(model.bannerForEnabled ? Color.Pink_03 : Color.Neutral_09)
                RoundedRectangle(cornerRadius: 10)
                    .stroke(model.bannerForEnabled ? Color.Pink_04 : Color.Neutral_07, lineWidth: 1)
            })
            .onTapGesture {
                model.cleanBanner()
            }
            .rotationEffect(uiAngle)
            .animation(
                .easeInOut(duration: 0.3),
                value: model.bannerText
            )
            .animation(.default, value: uiAngle)
    }

    // Photo preview from the CameraService
    private func cameraView(reader: GeometryProxy) -> some View {
        CameraPreview(session: camera.session)
            .frame(height: reader.size.width * 4.0 / 3.0)
            .gesture(
                MagnificationGesture()
                    .onChanged {
                        progressingScale = $0
                        camera.set(zoom: cameraScale * progressingScale)
                    }
                    .onEnded { _ in
                        cameraScale = camera.currentZoomFactor
                        progressingScale = 1
                    }
            )
            .overlay(
                gridView
            )
            .overlay(
                Group {
                    if camera.willCapturePhoto {
                        Color.black
                    }
                }
                .animation(
                    .easeInOut(duration: 0.1),
                    value: camera.willCapturePhoto
                )
            )
            .overlay {
                if camera.isProcessingPhoto {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color
                                .Neutral_01))
                }
            }
            .overlay {
                if model.bannerText != nil {
                    bannerView
                }
            }
    }

    private func topButtonsHStack() -> some View {
        HStack(spacing: 12) {
            closeButton.rotationEffect(uiAngle)
//            flashButton.rotationEffect(uiAngle)
            cameraRollButton.rotationEffect(uiAngle)
//            settingsButton.rotationEffect(uiAngle)
            Spacer()
            if model.multiPhotoEnabled, model.numberOfPhotos > 0 {
                imageButton.rotationEffect(uiAngle)
            }
        }
        .animation(.default, value: uiAngle)
        .padding(16)
    }

    private func bottomButtonsZStack() -> some View {
        ZStack {
            HStack(spacing: 19) {
                toggleAnnotationsButton.rotationEffect(uiAngle)
                toggleMultiPhotoButton.rotationEffect(uiAngle)
                Spacer()
                if model.multiPhotoEnabled {
                    nextButton.rotationEffect(uiAngle)
                }
            }
            .animation(.default, value: uiAngle)
            .padding(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
            HStack {
                takePhotoButton.padding(6)
            }
        }
    }

    // main view
    var body: some View {
        GeometryReader { reader in
            if horizontalSizeClass == .regular, verticalSizeClass == .regular {
                // "iPad" draft layout (present controls on top of the camera view)
                Color.Neutral_10.edgesIgnoringSafeArea(.all)
                VStack {
                    Spacer()
                    cameraView(reader: reader)
                        .overlay(topButtonsHStack(), alignment: .top)
                        .overlay(
                            VStack {
                                zoomView.rotationEffect(uiAngle)
                                    .animation(.default, value: uiAngle)
                                bottomButtonsZStack()
                            }.padding(.bottom, 22),
                            alignment: .bottom
                        )
                    Spacer()
                }
            } else {
                ZStack {
                    Color.Neutral_10.edgesIgnoringSafeArea(.all)
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        topButtonsHStack()
                        ZStack(alignment: .bottom) {
                            cameraView(reader: reader)
                            zoomView.rotationEffect(uiAngle)
                                .animation(.default, value: uiAngle)
                                .padding(.bottom, 22)
                        }
                        Spacer(minLength: 0)
                        bottomButtonsZStack()
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onRotate { newOrientation in
            // calculate new angle for ui elements when the device is rotated
            switch newOrientation {
            case .portraitUpsideDown:
                uiAngle = .degrees(180)
            case .landscapeLeft:
                uiAngle = .degrees(90)
            case .landscapeRight:
                uiAngle = .degrees(-90)
            default:
                uiAngle = .degrees(0)
            }
        }
    }
}

/// Custom view modifier to track rotation and call given action
struct DeviceRotationViewModifier: ViewModifier {
    let action: (UIDeviceOrientation) -> Void

    func body(content: Content) -> some View {
        content
            .onAppear()
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                action(UIDevice.current.orientation)
            }
    }
}

/// A View wrapper to make the `DeviceRotationViewModifier` easier to use
extension View {
    func onRotate(perform action: @escaping (UIDeviceOrientation) -> Void) -> some View {
        modifier(DeviceRotationViewModifier(action: action))
    }
}

struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CameraView(model: CameraViewModel(cameraService: CameraService()))
        }
    }
}
