import Foundation
@_spi(Restricted) @_spi(Experimental) import MapboxMaps
import UIKit

/// Converts selected area of Mapbox map to JPG.
/// It uses the Mapbox Snapshotter for snapshots taking. (Doesn't take snapshot of a map displayed on screen)
class MapboxSnapshotter {
    private var mapSnapshotter: Snapshotter?

    /// Converts the area pointed to by given cameraState with given areaSize (in view coordinates, in pixels)
    /// for given CanvasSourceData (to select a map style from) to a JPEG
    /// - Parameters:
    ///   - canvasSource - for map styling
    ///   - areaSize - size of the area to screenshot, in pixels, the middle point of this area is the camera center point
    ///   - cameraState - to decide which part of the map we want to screenshot (zoom, center, rotation)
    ///   - zoomConverter - required for adjusting the camera zoom to maximize the image resolution (and get a screenshot at a higher zoom level)
    func takeSnapshot(
        canvasSource: CanvasSource,
        areaSize: CGSize,
        cameraState: CameraState,
        zoomConverter: MapboxZoomConverter,
        completion: @escaping (Result<UIImage, Error>) -> Void
    ) {
        // -------------------------------------------------------------------------------------
        // Snapshot size vs pixelRatio.
        // screenshotAreaView is quite small in points.
        // If we want the screenshot with given size (4096x3072), we have 2 options:
        // 1. use the screenshotAreaView with current camera zoom level and adjust the
        //    pixelRatio to make the final image resolution higher
        //    - this works but takes the screenshot at a zoom level where the details
        //      are suited for screenshotAreaView size, so making it more dense doesn't help much,
        //      it only makes the roads, names higher res
        // 2. Adjust the size to be 4096x3072, at the same time adjust the camera zoom (zoom in),
        //    so it still shows the same real world bounds. So we just pretend we're on a bigger
        //    screen.
        //    - this will render a different zoom level tiles, but the end image will be really
        //      in higher "real map" resolution
        //    - the drawback is that it's not actually rendering the tiles user sees when taking
        //      screenshot, but potentially switches to a higher-res tiles level
        //    - when doing this procedure, we need to limit this procedure to the max mapbox zoom
        //      level, so in fact it'll be a mix of (2) and (1) if max level is reached

        let snapshotSize: CGSize
        let snapshotZoom: CGFloat

        // Limit the zoomIn linear factor to 4. It was chosen experimentally and is a good balance
        // between the real screenshot resolution (or the scaled areaSize) and the time of screenshot creation.
        // Also making the zoomIn factor bigger doesn't really bring much benefit as Mapbox doesn't have
        // a better quality images on higher zoom, but it still adjusts the vector data, so the
        // street names are getting smaller...)
        let expectedZoomIn = min(4, 4096 / max(areaSize.width, areaSize.height))

        // current zoom observed by user when taking the screenshot
        let initialZoom = cameraState.zoom
        // adjust the current zoom to make it * expectedZoomIn. We cannot just
        // mulitply as mapbox zoom is exponential, so we convert to a linear
        // value, multiply and convert back
        let initialMetersPerPoint = zoomConverter.getMetersPerPoint(forZoom: initialZoom)
        // we want to zoom in * expectedZoomIn, so we want less metersPerPoint
        let expectedMetersPerPoint = initialMetersPerPoint / expectedZoomIn
        let expectedZoom = zoomConverter.getZoom(forMetersPerPoint: expectedMetersPerPoint)

        snapshotZoom = min(expectedZoom, CanvasViewController.maxMapboxZoom)
//        print("camera zoom \(initialZoom) '*' \(expectedZoomIn) = \(expectedZoom), allowed = \(snapshotZoom)")

        // if we applied the maxMapboxZoom we need to go back to calculate the snapshotSize
        // we get from zooming in (if not we can still do it)
        let allowedMetersPerPoint = zoomConverter.getMetersPerPoint(forZoom: snapshotZoom)
        let allowedZoomIn = initialMetersPerPoint / allowedMetersPerPoint

        snapshotSize = CGSize(
            width: areaSize.width * allowedZoomIn,
            height: areaSize.height * allowedZoomIn
        )

        let snapshotPixelRatio = 4096 / max(
            snapshotSize.width,
            snapshotSize.height
        )
        let snapshotOptions = MapSnapshotOptions(
            size: snapshotSize, pixelRatio: snapshotPixelRatio,
            showsLogo: false, showsAttribution: false
        )
        var cameraOptions = CameraOptions(cameraState: cameraState)
        cameraOptions.zoom = snapshotZoom
        mapSnapshotter = Snapshotter(options: snapshotOptions)

        mapSnapshotter!._loadMapboxStyle(forCanvasSource: canvasSource) { error in
            if let error {
                completion(.failure(error))
            } else {
                self.mapSnapshotter?.setCamera(to: cameraOptions)
                self.mapSnapshotter?.start(overlayHandler: nil) { result in
                    switch result {
                    case let .success(image): completion(.success(image))
                    case let .failure(error): completion(.failure(error))
                    }
                }
            }
        }
    }
}
