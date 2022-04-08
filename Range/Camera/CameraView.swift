import AVFoundation
import Combine
import SwiftUI

class CameraViewModel: ObservableObject {
    let service: CameraService
    
    // translate the CameraService.currentZoomFactor to a string to be displayed in the view
    @Published var zoomString = ""
    
    private var subscriptions = Set<AnyCancellable>()
    
    init(service: CameraService) {
        self.service = service
        service.$currentZoomFactor.sink { [weak self] (zoom) in
            guard let self = self else { return }
            let zoomInt = Int(zoom)
            let zoomDecimal: Int = Int(10 * (zoom - Double(zoomInt)))
            if zoomDecimal == 0 {
                self.zoomString = "\(zoomInt)x"
            } else {
                self.zoomString = "\(zoomInt),\(zoomDecimal)x"
            }
        }
        .store(in: &self.subscriptions)
    }
}

struct CameraView: View {
    @ObservedObject var cameraService: CameraService
    @ObservedObject var model: CameraViewModel
    var closeAction: () -> Void
    var takePhotoAction: () -> Void
    
    init(cameraService: CameraService, closeAction: @escaping () -> Void, takePhotoAction: @escaping () -> Void) {
        self.cameraService = cameraService
        self.closeAction = closeAction
        self.takePhotoAction = takePhotoAction
        self.model = CameraViewModel(service: cameraService)
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
                        .foregroundColor(Color.Misc_White)
                )
        }.buttonStyle(.plain)
    }
    
    struct TakePhotoButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .foregroundColor(Color.Misc_White)
                .scaleEffect(configuration.isPressed ? 0.9 : 1)
                .animation(.easeInOut(duration: 0.05), value: configuration.isPressed)
        }
    }
    
    var takePhotoButton: some View {
        ZStack {
            Circle()
                .strokeBorder(Color.Misc_White, lineWidth: 4)
                .foregroundColor(.clear)
                .frame(width: 66, height: 66, alignment: .center)
            Button(action: takePhotoAction) {
                Circle()
                    .frame(width: 54, height: 54, alignment: .center)
            }.buttonStyle(TakePhotoButtonStyle())
        }
    }
    
    var zoomView: some View {
        Text(model.zoomString)
            .font(.system(size: 11)).fontWeight(.semibold)
            .foregroundColor(Color.Misc_White)
            .frame(width: 30, height: 30)
            .background(Circle().fill(Color.Misc_Black.opacity(0.8)))
    }
    
    var body: some View {
        GeometryReader { reader in
            ZStack {
                Color.Misc_Black.edgesIgnoringSafeArea(.all)
                VStack {
                    Spacer()
                    ZStack(alignment: .bottom) {
                        CameraPreview(session: cameraService.session)
                            .frame(height: reader.size.width * 4.0/3.0)
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

struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CameraView(cameraService: CameraService(), closeAction: {}, takePhotoAction: {})
        }
    }
}
