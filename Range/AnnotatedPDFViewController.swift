//
//  TestMapViewController.swift
//  Range
//
//  Created by raho on 18/03/2022.
//

import CoreLocation
@_spi(Restricted) @_spi(Experimental) import MapboxMaps
import PDFKit
import Turf
import UIKit


/**
 Displays background PDF with Mapbox map view on top.
 The mapbox map is receiving the user interactions and controls the PDF zoom/offset
 */
class AnnotatedPDFViewController: UIViewController {
    
    let centerCoordinate: CLLocationCoordinate2D
    let pdfPage: PDFPage
    let pdfScale: Double
    
    let zoomConverter: MapboxZoomConverter
    
    var mapView: MapView!
    var pdfScrollView: PDFPageScrollView!
    
    var initialMetersPerPoint: Double = 0.0
    var initialZoom: Double = 0.0
    
    init(centerCoordinate:CLLocationCoordinate2D, pdfPage: PDFPage, pdfScale: Double) {
        self.centerCoordinate = centerCoordinate
        self.pdfPage = pdfPage
        self.pdfScale = pdfScale
        self.zoomConverter = MapboxZoomConverter(latitude: centerCoordinate.latitude)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        
        setupPDFScrollView()
        
        setupInitialZoom()

        setupMapView()

        syncPDFViewWithCameraState()
        
        setupDebugViews()
    }
    
    private func setupPDFScrollView() {
        pdfScrollView = PDFPageScrollView(frame: view.bounds, pdfPage: pdfPage)
        // Allow for "inifite" scaling - the scale will be controlled and limited by the Mapbox zoom.
        pdfScrollView.minimumZoomScale = 0.0001
        pdfScrollView.maximumZoomScale = 1000
        view.addSubview(pdfScrollView)
    }
    
    /// Calculates initial mapbox zoom so the PDFPage fits the screen
    private func setupInitialZoom() {
        let pdfSizeInMeters = pdfPage.sizeInMeters(forScale: pdfScale)
        let pdfWidthMetersPerPoint = pdfSizeInMeters.width / view.bounds.width
        let pdfHeightMetersPerPoint = pdfSizeInMeters.height / view.bounds.height
        initialMetersPerPoint = max(pdfWidthMetersPerPoint, pdfHeightMetersPerPoint)
        initialZoom = zoomConverter.getZoom(forMetersPerPoint: initialMetersPerPoint)
    }
    
    private func setupMapView() {
        // TODO: remove the token or replace with Range one (it's from Rafal's private account)
        ResourceOptionsManager.default.resourceOptions.accessToken = "pk.eyJ1IjoicmFmYWwtcmFuZ2UiLCJhIjoiY2wwd210eHE5MGJlazNlbXlianYzMmFjMiJ9.6VWS7NDvOV1-ghpaWXITHw"
        let cameraOptions = CameraOptions(center: centerCoordinate, zoom: initialZoom)
        mapView = MapView(frame: view.bounds, mapInitOptions: MapInitOptions(cameraOptions: cameraOptions))
        mapView.alpha = 0.6
        do {
            try mapView.mapboxMap.setCameraBounds(with: CameraBoundsOptions(maxZoom:25.5))
        } catch {
            print("Unexpected error: \(error).")
        }
        
        mapView.ornaments.options.attributionButton.visibility = .hidden
        mapView.ornaments.options.scaleBar.visibility = .hidden
        
        mapView.gestures.options.pinchRotateEnabled = false
        mapView.gestures.options.pitchEnabled = false
        
        // Without this setting the .cameraChanged event reports wrong zoom data.
        // See https://github.com/mapbox/mapbox-maps-ios/issues/864 for more details.
        mapView.gestures.options.pinchBehavior = .doesNotResetCameraAtEachFrame
        
        mapView.mapboxMap.onEvery(.cameraChanged, handler: { [weak self] event in
            guard let self = self else { return }
            self.syncPDFViewWithCameraState()
        })
        
        view.addSubview(mapView)
    }
    
    private func setupDebugViews() {
        let resetButton = UIButton()
        resetButton.setTitle("reset", for: .normal)
        resetButton.addTarget(self, action: #selector(resetAction), for: .touchUpInside)
        resetButton.sizeToFit()
        resetButton.backgroundColor = .black.withAlphaComponent(0.5)
        view.addSubview(resetButton)
        resetButton.frame.origin = CGPoint(x: 10, y: 40)
    }
    
    @objc func resetAction() {
        mapView.camera.ease(to: CameraOptions(center: centerCoordinate, zoom: initialZoom), duration: 0.2)
    }
    
    /// Calculate and apply PDF zoom and offset based on current Mapbox camera state.
    private func syncPDFViewWithCameraState() {
        let cameraState = mapView.cameraState
        
        // translate current mapbox zoom to pdf UIView.zoomScale
        let currentMetersPerPoint = zoomConverter.getMetersPerPoint(forZoom: cameraState.zoom)
        pdfScrollView.zoomScale = initialMetersPerPoint / currentMetersPerPoint
        
        // translate the new camera center to adjustment in PDF offset
        let xCameraDistanceFromCenterMeters =  CLLocationCoordinate2D(latitude: centerCoordinate.latitude, longitude: cameraState.center.longitude).distance(to: centerCoordinate)
        let yCameraDistanceFromCenterMeters = CLLocationCoordinate2D(latitude: cameraState.center.latitude, longitude: centerCoordinate.longitude).distance(to: centerCoordinate)
        var xCameraDistanceFromCenterPoints = xCameraDistanceFromCenterMeters / currentMetersPerPoint
        var yCameraDistanceFromCenterPoints = yCameraDistanceFromCenterMeters / currentMetersPerPoint
        // if the map moves left (camera center moves right) then we need to move the views left
        if (cameraState.center.longitude > centerCoordinate.longitude) {
            xCameraDistanceFromCenterPoints *= -1
        }
        // if the map moves up (camera center moves down) then we need to move the views up
        if (cameraState.center.latitude < centerCoordinate.latitude) {
            yCameraDistanceFromCenterPoints *= -1
        }
        
        let midPdfPoint = CGPoint(x: mapView.center.x + xCameraDistanceFromCenterPoints, y: mapView.center.y + yCameraDistanceFromCenterPoints)
        
        var pdfOrigin = CGPoint()
        var contentOffset = CGPoint()
        if pdfScrollView.contentSize.width <= mapView.bounds.width {
            pdfOrigin.x = midPdfPoint.x - pdfScrollView.contentSize.width/2
        } else {
            contentOffset.x = -(midPdfPoint.x - pdfScrollView.contentSize.width/2)
        }
        if pdfScrollView.contentSize.height <= mapView.bounds.height {
            pdfOrigin.y = midPdfPoint.y - pdfScrollView.contentSize.height/2
        } else {
            contentOffset.y = -(midPdfPoint.y - pdfScrollView.contentSize.height/2)
        }
        pdfScrollView.pdfView.frame.origin = pdfOrigin
        pdfScrollView.contentOffset = contentOffset
    }
    
}
