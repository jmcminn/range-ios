import Foundation
import MapboxMaps
@_spi(Restricted) @_spi(Experimental) import MapboxMaps
import OSLog

/// extension for loading Range canvas sources
extension StyleManager {
    /// A default empty style for annotations with path to local glyphs
    var annotationsStyle: String {
        "{}"
//        guard let fontsPath = Bundle.main.path(forResource: "fonts", ofType: nil) else {
//            Logger.assets.fault("Couldn't find fonts, Mapbox will be broken")
//            return "{}"
//        }
//        return
//            """
//            {
//            "glyphs": "file://\(fontsPath)/{fontstack}/{range}.pbf"
//            }
//            """
    }

    func _loadMapboxStyle(forCanvasSource canvasSource: CanvasSource, completion: ((Error?) -> Void)? = nil) {
        switch canvasSource.type {
        case .pdf:
            loadMapboxStyle(forPdfSource: canvasSource, completion: completion)
        case .mapbox:
            _loadMapboxStyle(forMapboxSource: canvasSource, completion: completion)
        case .droneDeploy:
            _loadMapboxStyle(forDroneDeploySource: canvasSource, completion: completion)
        }
    }

    /// Load the style appropriate for pdf canvas source
    private func loadMapboxStyle(forPdfSource _: CanvasSource, completion: ((Error?) -> Void)? = nil) {
        load(mapStyle: MapStyle(json: annotationsStyle)) { error in
            if let error = error {
                Logger.mapbox.error("annotations style load failed: \(error.localizedDescription, privacy: .public)")
            }
            completion?(error)
        }
        // Show the map view behind the PDF for debugging
//        let styleUrl = "mapbox://styles/mapbox/streets-v12"
//        guard let styleURI = StyleURI(rawValue: styleUrl) else {
//            Logger.mapbox.error("invalid mapbox style \(styleUrl)")
//            completion?("invalid mapbox style \(styleUrl)")
//            return
//        }
//        load(mapStyle: MapStyle(uri: styleURI)) { error in
//            if let error {
//                Logger.mapbox.error(
//                    "failed to load mapbox style \(styleUrl) load failed: \(error.localizedDescription, privacy: .public)"
//                )
//            }
//            completion?(error)
//        }
    }

    /// Load mapbox style
    func _loadMapboxStyle(forMapboxSource source: CanvasSource, completion: ((Error?) -> Void)? = nil) {
        guard let styleUrl = source.styleUrl, let styleURI = StyleURI(rawValue: styleUrl) else {
            Logger.mapbox.error("invalid mapbox style \(source.styleUrl)")
            completion?("invalid mapbox style \(String(describing: source.styleUrl))")
            return
        }
        load(mapStyle: MapStyle(uri: styleURI)) { error in
            if let error {
                Logger.mapbox.error(
                    "failed to load mapbox style \(styleUrl) load failed: \(error.localizedDescription, privacy: .public)"
                )
            }
            completion?(error)
        }
    }

    /// Load drone deploy style
    func _loadMapboxStyle(
        forDroneDeploySource source: CanvasSource,
        completion: ((Error?) -> Void)? = nil
    ) {
        guard let styleUrl = source.styleUrl, let tilesetUrl = source.tilesetUrl,
              let styleURI = StyleURI(rawValue: styleUrl)
        else {
            Logger.mapbox.error("invalid mapbox style \(source.styleUrl)")
            completion?("invalid mapbox style \(String(describing: source.styleUrl))")
            return
        }
        load(mapStyle: MapStyle(uri: styleURI)) { [weak self] error in
            if let error {
                Logger.mapbox.error(
                    "failed to load mapbox style \(source.styleUrl) load failed: \(error.localizedDescription, privacy: .public)"
                )
                completion?(error)
                return
            }

            guard let self = self else { return }
            // Update the drone deploy layer source with drone deploy
            let droneDeployLayerId = "Custom endpoint layer"
            do {
                let droneDeployLayer = try self.layer(withId: droneDeployLayerId)
                let newDroneDeploySourceId = "droneDeploySource"
                var droneDeploySource = RasterSource(id: newDroneDeploySourceId)
                droneDeploySource.tiles = [tilesetUrl]
                droneDeploySource.tileSize = 256
                try self.addSource(droneDeploySource)
                var newDroneDeployLayer = RasterLayer(id: "droneDeployLayer", source: newDroneDeploySourceId)
                newDroneDeployLayer.minZoom = droneDeployLayer.minZoom
                newDroneDeployLayer.maxZoom = droneDeployLayer.maxZoom
                try self.addLayer(
                    newDroneDeployLayer,
                    layerPosition: LayerPosition.above(droneDeployLayerId)
                )
                try self.removeLayer(withId: droneDeployLayerId)
                completion?(nil)
            } catch {
                Logger.mapbox.error("Couldn't update the drone deploy layer \(droneDeployLayerId), \(error)")
                completion?(error)
            }
        }
    }
}
