import Foundation
import RealmSwift
import UIKit

/// Custom UIEvent sent by views to trigger certain actions and related to given `Object`
/// The way responder chain works forces us to pass objects (Upload, Comment, etc.) as Object as there's no way to use generics
/// to define the custom UIEvent (as they need to later match the signature of action functions which are Objective-C action(sender: Any?, event: UIEvent?)
/// (See "Discussion" in https://developer.apple.com/documentation/uikit/uiapplication/1622946-sendaction)
final class FlowEvent: UIEvent {
    enum Source {
        case media // the event is originating from the media collection view
    }

    let object: Object
    let source: Source?
    init(_ object: Object, source: Source? = nil) {
        self.object = object
        self.source = source
    }
}

/// Protocol defining actions that project flow can perform.
/// Required by the views sending actions, so they can use selectors for these functions.
/// See https://swiftrocks.com/understanding-the-ios-responder-chain.html for more info
@objc protocol ProjectFlowActions: AnyObject {
    /// show the Media card view controller with all project uploads
    func showMediaAction()
    /// Select and change the current canvas for project
    func selectCanvasAction()
    /// Show fullscreen media view for given upload
    func showFullscreenMediaAction(sender: Any?, event: FlowEvent)
    /// Show collaboration window for collaboration passed in the event
    func showCollaborationAction(sender: Any?, event: FlowEvent)
}

extension ProjectFlowController: ProjectFlowActions {
    func selectCanvasAction() {
        let canvases = [PDFCanvas](model.mainRealm.objects(PDFCanvas.self).sorted(by: \PDFCanvas.pageNumber))
        CanvasSelectorCardViewController(
            title: String(localized: "Source Selector"),
            canvases: canvases,
            selectedCanvas: model.currentCanvas,
            onCanvasSelected: { [weak self] canvas in
                guard let self = self else { return }
                guard self.model.currentCanvas != canvas else { return }
                self.model.currentCanvas = canvas
            }
        ).installAndShowCard(in: canvasContainer, inView: canvasContainer.controls)
    }

    func showMediaAction() {
        mediaVC = MediaCardViewController(
            projectModel: model,
            imageCaches: imageCaches,
            title: String(localized: "Media"),
            uploads: model.mainRealm.objects(Upload.self).where
                { $0.placeholder == false && $0.fileType == .image },
            onUploadSelected: { _ in
            }
        ).installAndShowCard(in: canvasContainer, inView: canvasContainer.controls)
    }

    func showFullscreenMediaAction(sender _: Any?, event: FlowEvent) {
        guard let upload = event.object as? Upload else { return }
        let fromMedia = event.source == .media
        fullscreenMediaVC = FullscreenMediaCardViewController(
            projectModel: model,
            imageCaches: imageCaches,
            upload: upload,
            // show button only from media, otherwise it's from collaboration so user can just close
            // the fullscreen media and be back in collaboration
            showCollaborationButton: fromMedia
        )
        .installAndShowCard(
            in: canvasContainer,
            inView: canvasContainer.controls,
            // media view already shows the overlay so don't show in this case
            showOverlay: !fromMedia
        )
    }

    func showCollaborationAction(sender _: Any?, event: FlowEvent) {
        guard let collaboration = event.object as? Collaboration,
              let geometry = collaboration.feature.first?.geometry.first,
              let canvas = geometry.canvas.first
        else { return }
        // update the canvas
        model.currentCanvas = canvas
        // reload the pins (it only reloads if canvas has changed)
        reloadGeometriesPinsDisplay(useNativeViews: debugSettings.nativeViewsForPins) {
            guard let pinsDisplay = self.pinsDisplay else { return }
            if let pin = pinsDisplay.pinForGeometryId(geometry.id) {
                // select the pin (which will trigger showing the collaboration window)
                pinsDisplay.setSelectedPin(pin)
                let canvasVC = self.canvasContainer.pdfCanvasViewController
                // pan the canvas to center on the pin
                canvasVC.animatePanAndZoom(
                    cameraCenter: pin.point.coordinates,
                    mapboxZoom: canvasVC.mapView.mapboxMap.cameraState.zoom
                )
            }
        }
    }
}
