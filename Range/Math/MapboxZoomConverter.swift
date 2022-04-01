import CoreLocation
import Foundation

let mercatorR = 6378137.0

/**
 Converter for mapbox zoom.
 
 Based on mapbox [getMetersPerPixelAtLatitude implementation](https://github.com/maplibre/maplibre-gl-native/blob/ea234edf67bb3aec75f077e15c1c30c99756b926/include/mbgl/util/projection.hpp#L47)
 */
struct MapboxZoomConverter {
    
    let metersPerPointToZoomConstant: Double
    let tileSize = 512.0
    
    /// The latitude is required for conversion because the real world size depends on the latitude.
    init(latitude: CLLocationDegrees) {
        metersPerPointToZoomConstant = cos(latitude * .pi / 180.0) * 2 * Double.pi * mercatorR / tileSize
    }
    
    func getZoom(forMetersPerPoint metersPerPoint: Double) -> Double {
        return log2(metersPerPointToZoomConstant / metersPerPoint);
    }
    
    func getMetersPerPoint(forZoom zoom: Double) -> Double {
        return metersPerPointToZoomConstant / exp2(zoom)
    }
}
