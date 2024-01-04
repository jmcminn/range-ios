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

struct PlaceAutocomplete {
    var id: String
    var center: CLLocationCoordinate2D
    var name: String
    var text: String
    /// the `name` returned by mapbox contains the `text` as its prefix, the description stores the name with text removed
    var description: String

    init(id: String, center: CLLocationCoordinate2D, name: String, text: String) {
        self.id = id
        self.center = center
        self.name = name
        self.text = text
        description = if name.hasPrefix(text) {
            String(name.dropFirst(text.count)).trimmingCharacters(in: .punctuationCharacters)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            name
        }
    }
}

/// Return an array of places autocompleted by given name using Mapbox's Forward  geocoding REST API (https://docs.mapbox.com/api/search/geocoding/#forward-geocoding)
func _placeAutocompletes(for name: String) async throws -> [PlaceAutocomplete] {
    let mapboxAccessToken: String = try! AppConfiguration.value(for: "MBXAccessToken")
    let urlEncodedName = try name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
        .or(error: "Cannot fetch places")
    let url = try URL(string:
        "https://api.mapbox.com/geocoding/v5/mapbox.places/\(urlEncodedName).json?access_token=\(mapboxAccessToken)")
        .or(error: "Cannot fetch places")
    let (data, _) = try await URLSession.shared.data(from: url)

    guard let response = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let features = response["features"] as? [[String: Any]]
    else {
        return []
    }

    return features.compactMap { feature in
        guard let id = feature["id"] as? String,
              let placeName = feature["place_name"] as? String,
              let centerCoordinates = feature["center"] as? [Double], centerCoordinates.count == 2,
              let text = feature["text"] as? String else { return nil }

        return PlaceAutocomplete(
            id: id,
            center: CLLocationCoordinate2D(latitude: centerCoordinates[1], longitude: centerCoordinates[0]),
            name: placeName,
            text: text
        )
    }
}
