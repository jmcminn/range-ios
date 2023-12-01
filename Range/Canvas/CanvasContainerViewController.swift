import Foundation
import MapboxMaps
import UIKit

/// View controller responsible for displaying background canvas (PDF, mapbox, ... background) +
/// container views displayed on top of the canvas
class CanvasContainerViewController: UIViewController {
    /// 2in1 canvas for displaying pdf(background) + mapbox(foreground).
    /// Displays the canvas (with mapview or pdf background)
    let canvasViewController: CanvasViewController

    let canvasFilters: CanvasFilters

    /// shortcut to access the annotations map view
    var annotationsMapView: MapView {
        canvasViewController.mapView
    }

    /// for presenting map content
    let content = PassthroughView()
    /// for presenting cards and other controls (on top of content)
    let controls = PassthroughView()

    init(
        model: ProjectModel,
        canvasFilters: CanvasFilters,
        canvasFileLoader: CanvasFileLoader,
        locationProvider: LocationProvider
    ) async throws {
        canvasViewController = try await CanvasViewController(
            model: model,
            canvasFileLoader: canvasFileLoader,
            locationProvider: locationProvider
        )
        self.canvasFilters = canvasFilters
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
        controls.backgroundColor = .clear

        content.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        controls.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    fileprivate func showPDF() {
        add(childController: canvasViewController, toView: content)
        canvasViewController.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
