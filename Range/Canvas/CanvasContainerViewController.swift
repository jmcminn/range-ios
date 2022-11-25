import Foundation
import MapboxMaps
import UIKit

/// View controller responsible for displaying background canvas (PDF, mapbox, ... background) +
/// foreground mapbox annotations mapView + container views displayed on top of the canvas
class CanvasContainerViewController: UIViewController {
    /// 2in1 canvas for displaying pdf(background) + mapbox(foreground).
    /// Will be refactored when we have option to present mapbox(background + foreground)
    let pdfCanvasViewController: PDFCanvasViewController

    /// shortcut to access the annotations map view
    var annotationsMapView: MapView {
        pdfCanvasViewController.mapView
    }

    /// for presenting map content
    let content = PassthroughView()
    /// for presenting cards and other controls (on top of content)
    let controls = PassthroughView()
    /// for presenting views on top of controls
    let overlays = PassthroughView()

    init(model: ProjectModel) async throws {
        pdfCanvasViewController = try await PDFCanvasViewController(model: model)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupContainers()
        showPDF()
    }

    fileprivate func setupContainers() {
        view.addSubview(content)
        view.addSubview(controls)
        view.addSubview(overlays)
        controls.backgroundColor = .clear
        overlays.backgroundColor = .clear

        content.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        controls.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        overlays.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    fileprivate func showPDF() {
        add(childController: pdfCanvasViewController, toView: content)
        pdfCanvasViewController.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
