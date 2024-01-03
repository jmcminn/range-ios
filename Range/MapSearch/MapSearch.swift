import CoreLocation
import Foundation

/// Return a Geocode result (place name)  from Mapbox's Geocoding REST API (https://docs.mapbox.com/api/search/geocoding/)
func _placeName(for location: CLLocationCoordinate2D) async throws -> String? {
    let mapboxAccessToken: String = try! AppConfiguration.value(for: "MBXAccessToken")
    let url = try URL(string:
        "https://api.mapbox.com/geocoding/v5/mapbox.places/\(location.longitude),\(location.latitude).json?access_token=\(mapboxAccessToken)")
        .or(error: "Cannot fetch place name")
    let (data, _) = try await URLSession.shared.data(from: url)

    if let response = try JSONSerialization.jsonObject(with: data) as? [String: Any],
       let features = response["features"] as? [Any],
       let feature = features.first as? [String: Any],
       let placeName = feature["place_name"] as? String
    {
        return placeName
    }

    return nil
}
