import UIKit
import SwiftUI

class CameraHostingController: UIHostingController<CameraView>, CardCoordinating {
    var onClose: (() -> Void)?
    var onPhotoTaken: ((Data?) -> Void)?
    var cardDisplayController: CardDisplayController?
    private let cameraService = CameraService()
    
    init() {
        
        super.init(rootView: CameraView(cameraService: cameraService, closeAction: {}, takePhotoAction: {}))
        
        self.rootView = CameraView(
            cameraService: cameraService,
            closeAction: { [weak self] in
                guard let self = self else { return }
                self.onClose?()
            }, takePhotoAction: { [weak self] in
                guard let self = self else { return }
                guard let onPhotoTaken = self.onPhotoTaken else { return }
                self.cameraService.capturePhoto(completion: onPhotoTaken)
            })
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        cameraService.configure() { sessionSetupResult in
            if sessionSetupResult == .configurationFailed {
                let alertController = UIAlertController(
                    title: "Camera Error",
                    message: "Camera configuration failed. Either your device camera is not available or its missing permissions.",
                    preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: { _ in
                    if let onClose = self.onClose {
                        onClose()
                    } else {
                        alertController.dismiss(animated: true)
                    }
                }))
                self.present(alertController, animated: true)
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        cameraService.start()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        cameraService.stop()
        super.viewWillDisappear(animated)
    }
    
    override dynamic var preferredStatusBarStyle: UIStatusBarStyle {
        UIStatusBarStyle.lightContent
    }
    
}

extension CameraHostingController: CardPresentable {
    func height(forWidth width: CGFloat, cardPosition: CardPosition) -> CGFloat {
        if cardPosition == .min {
            return 0
        } else if cardPosition == .medium {
            return -1 // not supported
        } else {
            return CGFloat.greatestFiniteMagnitude
        }
    }
}
