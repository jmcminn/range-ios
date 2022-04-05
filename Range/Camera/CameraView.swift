import AVFoundation
import Combine
import SwiftUI


struct CameraView: View {
    let cameraService: CameraService
    var closeAction: () -> Void
    var takePhotoAction: () -> Void
    
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
    
    var body: some View {
        GeometryReader { reader in
            ZStack {
                Color.Misc_Black.edgesIgnoringSafeArea(.all)
                VStack {
                    Spacer()
                    CameraPreview(session: cameraService.session)
                        .frame(height: reader.size.width * 4.0/3.0)
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
