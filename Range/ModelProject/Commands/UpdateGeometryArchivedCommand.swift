import FirebaseFirestore
import Foundation
import RealmSwift

/// Update archivedTimestamp for geometry
struct UpdateGeometryArchivedCommand: Command, Codable, Equatable {
    var operations: [CommandOperationType : [String]] {
        [.update: [collaborationId]]
    }

    let collaborationId: String
    var archivedTimestamp: Date?
}

extension UpdateGeometryArchivedCommand: LocalCommand {
    func apply(inRealm realm: Realm) throws {
        guard let geometry = realm.object(ofType: Collaboration.self, forPrimaryKey: collaborationId)?.geometry.first
        else {
            throw ModelError.geometryNotFound
        }

        geometry.archivedTimestamp = archivedTimestamp
    }
}

/// Provide data for firebase function call
extension UpdateGeometryArchivedCommand: FirebaseFunctionCommand {
    var functionName: String { "updateCollaboration" }

    var functionData: [String: Any?]? {
        [
            "collaborationId": collaborationId,
            "archivedTimestamp": archivedTimestamp.map { Int($0.timeIntervalSince1970 * 1000) } as Any,
        ]
    }
}
