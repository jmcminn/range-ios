import Foundation
import RealmSwift

struct AddFeatureCommand: Command {
    let featureId: String
    let geometryId: String
    let name: String
    let featureDescription: String

    func applyLocally(inRealm realm: Realm) throws {
        let geometry = realm.objectOrPlaceholder(ofType: Geometry.self, forPrimaryKey: geometryId)
        let feature = Feature(id: featureId, name: name, description: featureDescription)
        realm.add(feature, update: .modified)
        geometry.features.insert(feature)
    }
}
