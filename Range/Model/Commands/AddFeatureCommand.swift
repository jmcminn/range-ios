import Foundation
import RealmSwift

/// Add or update the `Feature`.
struct AddFeatureCommand: Command, Equatable {
    let featureId: String
    var geometryId: String
    var name: String
    var featureDescription: String?

    func apply(inRealm realm: Realm) throws {
        let geometry = realm.objectOrPlaceholder(ofType: Geometry.self, forPrimaryKey: geometryId)
        let feature = Feature(id: featureId, name: name, description: featureDescription)
        realm.add(feature, update: .modified)
        geometry.features.insert(feature)
    }
}
