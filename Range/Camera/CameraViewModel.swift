import AVFoundation
import Combine
import Foundation
import SwiftUI

/// View model for `CameraView`
class CameraViewModel: ObservableObject {
    /// Access to the camera properties
    let camera: CameraService
    let userPreferences: UserPreferences

    /// How many photos taken in this session
    @Published var numberOfPhotos: Int = 0
    /// The thumbnail to present for this photo session
    @Published var photoThumbnail: UIImage?
    /// Whether to show the tags/description screen after taking photo(s)
    @Published var annotationsEnabled: Bool
    /// Whether the option to take multiple photos is available to user
    @Published var multiPhotoAllowed = true { didSet {
        if !multiPhotoAllowed { multiPhotoEnabled = false }
    }}
    /// Whether to take multiple photos or 1 photo and annotate and place on the canvas
    @Published var multiPhotoEnabled: Bool
    /// The text to display temporarily over camera screen
    @Published var bannerText: String? = nil
    /// The icon to display temporarily over camera screen
    @Published var bannerIcon: String? = nil
    /// Fill and stroke for the banner background
    @Published var bannerFillColor: Color = .Neutral_09
    @Published var bannerStrokeColor: Color = .Neutral_07
    /// Delay for hiding the banner
    private var hideBannerDelayer = Delayer(delayTime: 2)
    /// Current flash mode
    @Published var flashMode: AVCaptureDevice.FlashMode = .auto
    /// Current zoom factor - which zoom factor from CameraService.zoomFactors should be marked as selected
    @Published var currentZoomFactorIndex: Int = 0

    /// the angle to use  for UI elements rotation when the device orientation changes
    @Published var uiAngle: Angle = .degrees(0)

    /// Callbacks for the controller
    var closeAction: (() -> Void)?
    var takePhotoAction: (() -> Void)?
    var nextAction: (() -> Void)?
    var cameraRollSelectAction: (() -> Void)?
    var photoThumbnailAction: (() -> Void)?

    /// translate the CameraService.currentZoomFactor to a string to be displayed in the view
    @Published var zoomString = ""

    private var subscriptions = Set<AnyCancellable>()

    init(cameraService: CameraService, userPreferences: UserPreferences) {
        camera = cameraService
        self.userPreferences = userPreferences

        annotationsEnabled = userPreferences.annotationEnabled
        multiPhotoEnabled = userPreferences.multiPhotoSessionEnabled

        // update zoomString when the @Published CameraService.$currentZoomFactor changes
        let onCurrentZoomUpdated: (Double) -> Void = { [weak self] zoom in
            guard let self = self else { return }
            self.zoomString = zoomToString(zoom, currentZoom: true)
            self.currentZoomFactorIndex = currentZoomFactorIndex(zoom)
        }

        // add a listener for changes to service.$currentZoomFactor and hold a strong reference to it
        cameraService.$currentZoomFactor.sink(receiveValue: onCurrentZoomUpdated).store(in: &subscriptions)
    }

    /// just find the position of zoom in the array of factors.
    /// For example if factors are [1, 2, 3] and zoom is 2.1 then the index is 1 (corresponding to zoom factor = 2)
    /// This could be binary search but currently the max number of zoom factors is 4, so a simple for loop will suffice
    func currentZoomFactorIndex(_ zoom: Double) -> Int {
        var index = 0
        // if there's a next factor check if it's better
        while index < camera.zoomFactors.count - 1, zoom >= camera.zoomFactors[index + 1] {
            index += 1
        }
        return index
    }

    /// currentZoom (`true`) renders differently that zoom factors (as in iOS Camera app)
    func zoomToString(_ zoom: Double, currentZoom: Bool) -> String {
        // convert to value to be presented in UI (see the docs for zoomFactorUIMultiplier)
        let displayZoom = zoom * camera.zoomFactorUIMultiplier
        let zoomInt = Int(displayZoom)
        let zoomDecimal: Int = .init(10 * (displayZoom - Double(zoomInt)))
        if currentZoom {
            if zoomDecimal == 0 {
                return "\(zoomInt)×"
            } else {
                return "\(zoomInt).\(zoomDecimal)×"
            }
        } else {
            // no front 0 for 0.5, only if 0.0
            if zoomDecimal == 0 {
                return "\(zoomInt)"
            } else if zoomInt == 0 {
                return ".\(zoomDecimal)"
            } else {
                return "\(zoomInt).\(zoomDecimal)"
            }
        }
    }

    /// Toggles the `annotationsEnabled` flag and sets the `bannerText`/`bannerIcon`
    func toggleAnnotations() {
        annotationsEnabled = !annotationsEnabled
        userPreferences.annotationEnabled = annotationsEnabled
        setBanner(
            text: "Annotation " + (annotationsEnabled ? "enabled" : "disabled"),
            icon: "tag",
            fillColor: annotationsEnabled ? Color.Pink_03 : Color.Neutral_09,
            strokeColor: annotationsEnabled ? Color.Pink_04 : Color.Neutral_07
        )
    }

    /// Toggles the `multiPhotoEnabled` flag and sets the `bannerText`/`bannerIcon`
    func toggleMultiPhoto() {
        multiPhotoEnabled = !multiPhotoEnabled
        userPreferences.multiPhotoSessionEnabled = multiPhotoEnabled
        setBanner(
            text: "Multi-photo session " + (multiPhotoEnabled ? "enabled" : "disabled"),
            icon: "photo.on.rectangle",
            fillColor: multiPhotoEnabled ? Color.Pink_03 : Color.Neutral_09,
            strokeColor: multiPhotoEnabled ? Color.Pink_04 : Color.Neutral_07
        )
    }

    /// Toggle auto => off => on => auto => ...
    /// And sets the `bannerText`/`bannerIcon`
    func toggleFlashMode() {
        let bannerText: String
        let bannerIcon: String
        switch flashMode {
        case .auto:
            flashMode = .off
            bannerText = String(localized: "Flash disabled")
            bannerIcon = "bolt.slash.fill"
        case .off:
            flashMode = .on
            bannerText = String(localized: "Flash enabled")
            bannerIcon = "bolt.fill"
        case .on:
            flashMode = .auto
            bannerText = String(localized: "Auto flash enabled")
            bannerIcon = "bolt.badge.a.fill"
        @unknown default:
            fatalError("flashMode not supported") // this shouldn't happen as the app only allows to select one of the above
        }
        setBanner(text: bannerText, icon: bannerIcon, fillColor: .Orange_03, strokeColor: .Orange_04)
    }

    /// Sets given banner and schedule it's cleanup in the future (cancel any already scheduled cleanup)
    func setBanner(text: String, icon: String, fillColor: Color, strokeColor: Color) {
        bannerIcon = icon
        bannerText = text
        bannerFillColor = fillColor
        bannerStrokeColor = strokeColor
        // new delay for banner hiding after text set/update
        hideBannerDelayer.delay { [weak self] in
            self?.cleanBanner()
        }
    }

    /// Cleans the banner data
    func cleanBanner() {
        bannerText = nil
        bannerIcon = nil
    }
}
