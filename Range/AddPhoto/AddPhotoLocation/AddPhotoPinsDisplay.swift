import CoreLocation
import MapboxMaps
import OSLog
import RealmSwift
import SnapKit
import Turf
import UIKit

/// Handles the pins when adding a photo annotation
/// It uses ghe GeometriesPinsDisplay to actually display the pins on the canvas and additionally manages the photo pin view (a special
/// pin showing the photo being added) and tooltip views.
/// It also listen for map interaction events and auto select pins that are closest to the screen center (and within the `pinsSearchRectSize`)
class AddPhotoPinsDisplay {
    unowned let canvasContainer: CanvasContainerViewController
    unowned let canvasVC: CanvasViewController
    unowned let model: ProjectModel
    let geometriesPinsDisplay: GeometriesPinsDisplay
    let image: UIImage

    // Initialize Impact Feedback Generator
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)

    /// Defines the size of the rectangle used for searching pins near to the photo pin (or screen center)
    private let pinsSearchRectSize = 30.0

    /// selected pin or nil if nothing is selected and we're showing the `photoPin`
    var selectedPin: PinPoint? { geometriesPinsDisplay.selectedPin }

    /// Notifies about change in selected pin
    var onSelectedPinChange: ((PinPoint?) -> Void)?

    /// the pin displaying a photo thumb - used for selecting a new location for the image
    private(set) var photoPinView: PhotoPin?

    /// tooltip shown for a currently selected pin
    private var selectedPinTooltip: MapTooltipView?
    /// tooltip shown for photoPinView
    private var photoPinTooltip: MapTooltipView?

    /// id of registered delegate
    private var canvasDelegateId: UUID?

    /// - Parameters:
    ///   - canvas:             handler will add pins for this canvas
    ///   - canvasContainer:    handler will add pins to this canvas view
    ///   - image:              image to be displayed on the new photo pin
    init(canvas: Canvas, canvasContainer: CanvasContainerViewController, model: ProjectModel, image: UIImage) {
        self.canvasContainer = canvasContainer
        canvasVC = canvasContainer.canvasViewController
        self.model = model
        self.image = image
        geometriesPinsDisplay = DebugSettings().nativeViewsForPins
            ? GeometriesViewAnnotationPinsDisplay(
                canvas: canvas,
                canvasViewController: canvasContainer.canvasViewController,
                deselectOnCanvasTap: false,
                showArchivedPins: UserSettings().showArchivedCollaborations,
                geometryPinDisplayOptionsProvider: PinDisplayOptions.addPhotoDisplayOptionsProvider
            )
            : GeometriesAnnotationPinsDisplay(
                canvas: canvas,
                canvasViewController: canvasContainer.canvasViewController,
                deselectOnCanvasTap: false,
                showArchivedPins: UserSettings().showArchivedCollaborations,
                geometryPinDisplayOptionsProvider: PinDisplayOptions.addPhotoDisplayOptionsProvider
            )
        geometriesPinsDisplay.onSelectedPinChange = { [weak self] pinPoint in
            self?.onSelectedPinChanged(pinPoint: pinPoint)
        }

        feedbackGenerator.prepare()
    }

    func start() {
        installPhotoPinView()
        geometriesPinsDisplay.start(onInitialLoad: { [weak self] in
            // on first load we need to see if there's a pin matching lastPhotoPinId
            self?.selectInitialPin()
        })
        canvasDelegateId = canvasVC.addDelegate(self)
    }

    func stop() {
        if let id = canvasDelegateId {
            canvasVC.removeDelegate(id: id)
        }
        geometriesPinsDisplay.stop()
        photoPinView?.removeFromSuperview()
        hideTooltip()
    }

    /// Checks if one of initially loaded pins matches ``lastPhotoPinId``, if so selects and animates to it.
    /// Otherwise show photo pin in the center of the screen
    private func selectInitialPin() {
        if let lastPhotoPinId = UserDefaults.lastPhotoPinId,
           let lastPhotoPin = geometriesPinsDisplay.pinForGeometryId(lastPhotoPinId)
        {
            geometriesPinsDisplay.setSelectedPin(lastPhotoPin)
            canvasVC.animatePanAndZoom(
                cameraCenter: lastPhotoPin.point.coordinates,
                mapboxZoom: canvasVC.mapView.mapboxMap.cameraState.zoom
            )
        } else {
            updatePhotoPinVisibility()
        }
        if selectedPin != nil {
            showSelectedPinTooltip()
        } else {
            showPhotoPinTooltip()
        }
    }

    /// when observed selected pin change in the pins display
    private func onSelectedPinChanged(pinPoint: PinPoint?) {
        updatePhotoPinVisibility()
        if pinPoint != nil {
            if DebugSettings().hapticFeedbackOnPinTapSelection {
                feedbackGenerator.impactOccurred()
                feedbackGenerator.prepare()
                hideTooltip()
                showSelectedPinTooltip()
            }
        }
        // forward to observer
        onSelectedPinChange?(pinPoint)
    }
}

/// Handling of tooltips for the pins.
/// There are 2 kinds of tooltips
/// 1. tooltip for mapbox pink pins that are displayed as Mapbox annotations (https://docs.mapbox.com/ios/maps/guides/annotations/view-annotations/)
///      They are added as mapbox view annotations because they need to follow the pins when the canvas is panned.
/// 2. tooltip for photo pin - added as a native view because it needs to stay center over the photo pin view
extension AddPhotoPinsDisplay {
    /// Hide tooltip if any presented (either feature or photo tooltip)
    private func hideTooltip() {
        if let tooltip = selectedPinTooltip {
            canvasVC.mapView.viewAnnotations.remove(tooltip)
            selectedPinTooltip = nil
        }
        if let tooltip = photoPinTooltip {
            tooltip.removeFromSuperview()
            photoPinTooltip = nil
        }
    }

    /// Shows the tooltip for the selected pin using mapbox view annotations.
    private func showSelectedPinTooltip() {
        hideTooltip()
        guard let pin = selectedPin else { return }

        let tooltip = MapTooltipView(
            text: pin.id == UserDefaults.lastPhotoPinId ? "Use last location" : "Use this location",
            boxColor: .Secondary_02
        )
        let fittingSize = CGSize(
            width: canvasVC.mapView.frame.size.width,
            height: UIView.layoutFittingExpandedSize.height
        )
        let tooltipSize = tooltip.systemLayoutSizeFitting(fittingSize)
        let tooltipOptions = ViewAnnotationOptions(
            geometry: pin.point,
            width: tooltipSize.width.rounded(.up), // with no rounding the text was truncated...
            height: tooltipSize.height.rounded(.up),
            allowOverlap: true,
            anchor: .bottom,
            offsetY: 53,
            selected: true
        )
        tooltip.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
        UIView.animate(withDuration: 0.2) {
            tooltip.transform = CGAffineTransform(scaleX: 1, y: 1)
        }
        try? canvasVC.mapView.viewAnnotations.add(tooltip, options: tooltipOptions)
        selectedPinTooltip = tooltip
    }

    /// Shows the tooltip for the photo pin as a native view added to the canvasContainer content
    private func showPhotoPinTooltip() {
        hideTooltip()
        guard photoPinTooltip == nil else { return } // already shown
        let tooltip = MapTooltipView(text: "New location", boxColor: .Green_03)
        canvasContainer.content.addSubview(tooltip)
        tooltip.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            // center pin tip on the screen center (the asset has insets defined to ignore shadow)
            make.bottom.equalTo(canvasContainer.content.snp.centerY).offset(-53)
        }
        tooltip.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
        UIView.animate(withDuration: 0.2) {
            tooltip.transform = CGAffineTransform(scaleX: 1, y: 1)
        }
        photoPinTooltip = tooltip
    }
}

/// Handling of photo pin which is a special pin that is displayed as a native view in the center of the screen.
/// It acts a pointer for selecting a new pin coordinates by panning and zooming the canvas)
extension AddPhotoPinsDisplay {
    /// This creates photo pin view (if not created yet) and adds to canvas content.
    private func installPhotoPinView() {
        guard photoPinView == nil else { return }

        let initialStatusColor = model.mainRealm.objects(Status.self).first(where: { $0.isInitial })?
            .color ?? .Primary_Blue_04
        let pin = PhotoPin(image: image, taskPinColor: initialStatusColor)
        canvasContainer.content.addSubview(pin)
        pin.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        pin.isHidden = true
        photoPinView = pin
    }

    /// Animates showing or hiding the photo pin based on currently selectedPin (if no pin selected then show the photo pin)
    private func updatePhotoPinVisibility() {
        if selectedPin != nil {
            // pink pin selected, animate out the photo pin
            UIView.animate(withDuration: 0.2) {
                self.photoPinView?.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
            } completion: { _ in
                self.photoPinView?.isHidden = self.selectedPin != nil
            }
        } else {
            // no pink pin selected, animate in the photo pin
            photoPinView?.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
            photoPinView?.isHidden = selectedPin != nil
            UIView.animate(withDuration: 0.2) {
                self.photoPinView?.transform = CGAffineTransform(scaleX: 1, y: 1)
            }
        }
    }
}

/// Canvas user interactions handling
extension AddPhotoPinsDisplay: CanvasViewControllerDelegate {
    /// Reset selected pin if user panned the map
    func canvasCameraChanged(reason: CanvasCameraChangeReason) {
        if reason == .pan || reason == .zoom {
            hideTooltip()
            geometriesPinsDisplay.findPin(
                closestToPoint: canvasVC.mapView.center,
                searchSquareSize: pinsSearchRectSize
            ) { pin in
                // either select the closest feature or deselect if no feature found
                if self.selectedPin?.id != pin?.id {
                    self.feedbackGenerator.impactOccurred()
                    self.feedbackGenerator.prepare()
                    self.geometriesPinsDisplay.setSelectedPin(pin)
                }
            }
        } else if reason == .panEnd {
            // show the tooltip after the pan gesture has ended
            if let selectedPin = selectedPin {
                showSelectedPinTooltip()
                if DebugSettings().centerCanvasOnPinSnap {
                    canvasVC.animatePanAndZoom(
                        cameraCenter: selectedPin.point.coordinates,
                        mapboxZoom: canvasVC.mapView.mapboxMap.cameraState.zoom
                    )
                }
            } else {
                showPhotoPinTooltip()
            }
        }
    }

    func canvasTapRecognized(at _: CGPoint) {}
}
