import FirebaseFirestore
import Foundation
import RealmSwift

/// Delete the `Collaboration`(s)
struct DeleteCollaborationsCommand: Command, Codable, Equatable {
    var type: CommandType { .delete } // don't make it a stored property, so it's not encoded
    var targetIds: Set<String> { .init(geometryIds + collaborationIds) }

    // remote delete uses geometryId only, there's a cascading delete in Firestore based on geometry
    let geometryIds: [String]
    // local delete uses collaborationId to find all local related objects and remove them
    let collaborationIds: [String]
}

extension DeleteCollaborationsCommand: LocalCommand {
    func apply(inRealm realm: Realm) throws {
        for collaborationId in collaborationIds {
            // fail locally if the collaboration doesn't exist, this shouldn't really happen
            guard let collaboration = realm.object(ofType: Collaboration.self, forPrimaryKey: collaborationId) else {
                throw ModelError.collaborationNotFound
            }
            guard let feature = collaboration.feature.first else {
                throw ModelError.featureNotFound
            }
            guard let geometry = feature.geometry.first else {
                throw ModelError.geometryNotFound
            }
            realm.delete(collaboration.comments)
            realm.delete(collaboration.updates)
            realm.delete(collaboration.uploads)
            realm.delete(geometry)
            realm.delete(feature)
            realm.delete(collaboration)
        }
    }
}

extension DeleteCollaborationsCommand: FirestoreCommand {
    func apply(inFirestore ctx: FirestoreCommandContext) throws {
        // ------------- READS -----------------
        // check that target exists, otherwise it's already removed
        let geometriesToDelete = try geometryIds.filter { try ctx.exists(.geometry($0)) }

        // ------------- WRITES ----------------
        for geometryId in geometriesToDelete {
            ctx.deleteDocument(.geometry(geometryId))
        }
    }
}
