import AVFoundation
import Combine
import Foundation
import SwiftUI

/// View model for `CameraView`
class CameraViewModel: ObservableObject {
    /// Access to the camera properties
    let camera: CameraService

    /// How many photos taken in this session
    @Published var numberOfPhotos: Int = 0
    /// The thumbnail to present for this photo session
    @Published var photoThumbnail: UIImage?
    /// Whether to show the tags/description screen after taking photo(s)
    @Published var annotationsEnabled = UserDefaults.annotationEnabled
    /// Whether to take multiple photos or 1 photo and annotate and place on the canvas
    @Published var multiPhotoEnabled = UserDefaults.multiPhotoSessionEnabled
    /// The text to display temporarily over camera screen
    @Published var bannerText: String? = nil
    /// The icon to display temporarily over camera screen
    @Published var bannerIcon: String? = nil
    /// Whether the banner is for enabled or disabled state
    @Published var bannerForEnabled: Bool = false
    /// Currently scheduled banner cleanup
    private var cleanWorkItem: DispatchWorkItem?

    /// Callbacks for the controller
    var closeAction: (() -> Void)?
    var takePhotoAction: (() -> Void)?
    var nextAction: (() -> Void)?

    /// translate the CameraService.currentZoomFactor to a string to be displayed in the view
    @Published var zoomString = ""

    private var subscriptions = Set<AnyCancellable>()

    init(cameraService: CameraService) {
        camera = cameraService

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
        cameraService.$currentZoomFactor.sink(receiveValue: updateZoomString).store(in: &subscriptions)
    }

    /// Toggles the `annotationsEnabled` flag and sets the `bannerText`/`bannerIcon`
    func toggleAnnotations() {
        annotationsEnabled = !annotationsEnabled
        UserDefaults.annotationEnabled = annotationsEnabled
        setBanner(
            text: "Annotation " + (annotationsEnabled ? "enabled" : "disabled"),
            icon: "tag",
            forEnabled: annotationsEnabled
        )
    }

    /// Toggles the `multiPhotoEnabled` flag and sets the `bannerText`/`bannerIcon`
    func toggleMultiPhoto() {
        multiPhotoEnabled = !multiPhotoEnabled
        UserDefaults.multiPhotoSessionEnabled = multiPhotoEnabled
        setBanner(
            text: "Multi-photo session " + (multiPhotoEnabled ? "enabled" : "disabled"),
            icon: "photo.on.rectangle",
            forEnabled: multiPhotoEnabled
        )
    }

    /// Sets given banner and schedule it's cleanup in the future (cancel any already scheduled cleanup)
    func setBanner(text: String, icon: String, forEnabled: Bool) {
        bannerIcon = icon
        bannerText = text
        bannerForEnabled = forEnabled
        // cancel the current cleanWorkItem to prolong banner showing
        if let cleanWorkItem = cleanWorkItem {
            cleanWorkItem.cancel()
        }
        // schedule `cleanBanner` in 2 seconds
        let newCleanWorkItem = DispatchWorkItem { [weak self] in
            self?.cleanBanner()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2), execute: newCleanWorkItem)
        cleanWorkItem = newCleanWorkItem
    }

    /// Cleans the banner data
    func cleanBanner() {
        bannerText = nil
        bannerIcon = nil
    }
}
