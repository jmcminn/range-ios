import FirebaseFirestore
import Foundation
import RealmSwift

/// Update archivedTimestamp for geometry
struct UpdateGeometryArchivedCommand: Command, Codable, Equatable {
    var type: CommandType { .update } // don't make it a stored property, so it's not encoded
    var targetIds: [String] { .init([collaborationId]) }

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

    func functionData(_ projectId: String) -> Any? {
        [
            "projectId": projectId,
            "collaborationId": collaborationId,
            "archivedTimestamp": archivedTimestamp.map { Int($0.timeIntervalSince1970 * 1000) } as Any,
        ]
    }
}
