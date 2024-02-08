import AVFoundation
import Combine
import SwiftUI

/// # CameraView
///
/// The main camera view with a pinch-zoomable photo preview and buttons to take a photo or cancel
struct CameraView: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass

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
    // The 0.0 initial value is used to mark that the value needs to be obtained from the camera zoom
    // when used for the first time
    @State var cameraScale: CGFloat = 0.0
    // progress of the current MagnificationGesture
    @State var progressingScale: CGFloat = 1.0

    var closeButton: some View {
        Button(action: model.closeAction ?? {}) {
            Circle()
                .strokeBorder(Color.Neutral_07, lineWidth: 1)
                .background(Circle().fill(Color.Neutral_09))
                .frame(width: 40, height: 40)
                .overlay(Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.Red_03))
        }.buttonStyle(.plain)
    }

    var flashButton: some View {
        Button(action: model.toggleFlashMode) {
            switch model.flashMode {
            case .on:
                Circle()
                    .strokeBorder(Color.Neutral_07, lineWidth: 1)
                    .background(Circle().fill(Color.Neutral_09))
                    .frame(width: 40, height: 40)
                    .overlay(Image(systemName: "bolt.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.Orange_03))
            case .auto:
                Circle()
                    .strokeBorder(Color.Neutral_07, lineWidth: 1)
                    .background(Circle().fill(Color.Neutral_09))
                    .frame(width: 40, height: 40)
                    .overlay(Image(systemName: "bolt.badge.a.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.Neutral_04))
            case .off:
                Circle()
                    .strokeBorder(Color.Neutral_07, lineWidth: 1)
                    .background(Circle().fill(Color.Neutral_09))
                    .frame(width: 40, height: 40)
                    .overlay(Image(systemName: "bolt.slash.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.Neutral_04))
            @unknown default:
                fatalError("flashMode not supported") // this shouldn't happen as the app only allows to select one of the above
            }
        }.buttonStyle(.plain)
    }

    var cameraRollButton: some View {
        Button(action: model.cameraRollSelectAction ?? {}) {
            Circle()
                .strokeBorder(Color.Neutral_07, lineWidth: 1)
                .background(Circle().fill(Color.Neutral_09))
                .frame(width: 40, height: 40)
                .overlay(Image(systemName: "photo")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.Neutral_04))
        }.buttonStyle(.plain)
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
        Button(action: model.photoThumbnailAction ?? {}) {
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
                .overlay(Image(systemName: "tag")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(model.multiPhotoEnabled ? .Neutral_01 : .Neutral_04))
        }.buttonStyle(.plain)
    }

    var toggleMultiPhotoButton: some View {
        Button(action: model.toggleMultiPhoto) {
            Circle()
                .strokeBorder(model.multiPhotoEnabled ? Color.Pink_04 : Color.Neutral_07, lineWidth: 2)
                .background(Circle().fill(model.multiPhotoEnabled ? Color.Pink_03 : Color.Neutral_09))
                .frame(width: 50, height: 50)
                .overlay(Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(model.multiPhotoEnabled ? .Neutral_01 : .Neutral_04))
        }.buttonStyle(.plain)
    }

    var nextButton: some View {
        Button(action: model.nextAction ?? {}) {
            Circle()
                .strokeBorder(Color.Primary_Blue_06, lineWidth: 2)
                .background(Circle().fill(Color.Primary_Blue_04))
                .frame(width: 50, height: 50)
                .overlay(Image(systemName: "arrow.forward")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.Neutral_01))
        }.buttonStyle(.plain)
            .disabled(model.numberOfPhotos == 0 || camera.isProcessingPhoto)
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
    private func zoomView(zoomFactorIndex: Int) -> some View {
        let zoom = camera.zoomFactors[zoomFactorIndex]
        return Button(action: {
            cameraScale = zoom
            camera.set(zoom: zoom, animated: true)
        }) {
            if zoomFactorIndex == model.currentZoomFactorIndex {
                // show current zoom for current zoom factor (so show for example 2.3 and not 2 because
                // zoom might not be exactly one of the zoom factors)
                Text(model.zoomString)
                    .font(.system(size: 13)).fontWeight(.semibold)
                    .foregroundColor(Color.Pink_03)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.Neutral_10.opacity(0.8)))
            } else {
                Text(model.zoomToString(zoom, currentZoom: false))
                    .font(.system(size: 11)).fontWeight(.semibold)
                    .foregroundColor(Color.Neutral_01)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.Neutral_10.opacity(0.8)))
                    .padding(4)
            }
        }
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
                RoundedRectangle(cornerRadius: 10).fill(model.bannerFillColor)
                RoundedRectangle(cornerRadius: 10).stroke(model.bannerStrokeColor, lineWidth: 1)
            })
            .onTapGesture {
                model.cleanBanner()
            }
            .rotationEffect(model.uiAngle)
            .animation(
                .easeInOut(duration: 0.3),
                value: model.bannerText
            )
            .animation(.default, value: model.uiAngle)
    }

    // Photo preview from the CameraService
    private func cameraView(reader: GeometryProxy) -> some View {
        CameraPreview(cameraService: camera, tappedCallback: { _, captureDevicePoint in
            // focus camera when tapping the CameraPreview view
            camera.focus(onCaptureDevicePoint: captureDevicePoint)
        })
        .frame(height: reader.size.width * 4.0 / 3.0)
        .gesture(
            MagnificationGesture()
                .onChanged {
                    if cameraScale <= 0.0 {
                        cameraScale = camera.currentZoomFactor
                    }
                    progressingScale = $0
                    camera.set(zoom: cameraScale * progressingScale, animated: false)
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

    private func topButtons() -> some View {
        ZStack {
            HStack {
                closeButton.rotationEffect(model.uiAngle)
                Spacer()
                if model.multiPhotoEnabled, model.numberOfPhotos > 0 {
                    imageButton.rotationEffect(model.uiAngle)
                }
            }
            // centered
            HStack(spacing: 12) {
                if camera.hasFlash {
                    flashButton.rotationEffect(model.uiAngle)
                }
                if model.cameraRollSelectAction != nil {
                    cameraRollButton.rotationEffect(model.uiAngle)
                }
                //            settingsButton.rotationEffect(model.uiAngle)
            }
        }
        .animation(.default, value: model.uiAngle)
        .padding(16)
    }

    private func zoomButtons() -> some View {
        HStack(spacing: 2) {
            ForEach(0 ..< camera.zoomFactors.count, id: \.self) { index in
                zoomView(zoomFactorIndex: index).rotationEffect(model.uiAngle)
            }
        }
        .animation(.default, value: model.uiAngle)
    }

    private func bottomButtons() -> some View {
        ZStack {
            HStack(spacing: 19) {
                toggleAnnotationsButton.rotationEffect(model.uiAngle)
                if model.multiPhotoAllowed {
                    toggleMultiPhotoButton.rotationEffect(model.uiAngle)
                }
                Spacer()
                if model.multiPhotoEnabled {
                    nextButton.rotationEffect(model.uiAngle)
                }
            }
            .animation(.default, value: model.uiAngle)
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
                        .overlay(topButtons(), alignment: .top)
                        .overlay(
                            VStack {
                                zoomButtons()
                                bottomButtons()
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
                        topButtons()
                        ZStack(alignment: .bottom) {
                            cameraView(reader: reader)
                            zoomButtons()
                                .padding(.bottom, 22)
                        }
                        Spacer(minLength: 0)
                        bottomButtons()
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .navigationBarHidden(true)
    }
}

struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CameraView(model: CameraViewModel(cameraService: CameraService()))
        }
    }
}
