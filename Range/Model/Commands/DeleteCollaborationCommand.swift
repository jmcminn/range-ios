import FirebaseFirestore
import Foundation
import RealmSwift

/// Delete the `Collaboration`
struct DeleteCollaborationCommand: Command, Codable, Equatable {
    // remote delete uses geometryId only, there's a cascading delete in Firestore based on geometry
    let geometryId: String
    // local delete uses collaborationId to find all local related objects and remove them
    let collaborationId: String
}

extension DeleteCollaborationCommand: LocalCommand {
    func apply(inRealm realm: Realm) throws {
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

extension DeleteCollaborationCommand: FirestoreCommand {
    func apply(inFirestore ctx: FirestoreCommandContext) throws {
        // ------------- READS -----------------
        // check that target exists, otherwise it's already removed
        guard try ctx.exists(.geometry(geometryId)) else { return }

        // ------------- WRITES ----------------
        ctx.deleteDocument(.geometry(geometryId))
    }
}
