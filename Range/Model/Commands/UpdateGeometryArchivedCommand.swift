import FirebaseFirestore
import Foundation
import RealmSwift

/// Update archivedTimestamp for geometry
struct UpdateGeometryArchivedCommand: Command, Codable, Equatable {
    let geometryId: String
    var archive: Bool
}

extension UpdateGeometryArchivedCommand: LocalCommand {
    func apply(inRealm realm: Realm) throws {
        guard let geometry = realm.object(ofType: Geometry.self, forPrimaryKey: geometryId) else {
            throw ModelError.geometryNotFound
        }
        geometry.archivedTimestamp = archive ? Date.now : nil
    }
}

/// Apply the `Comment` update in Firestore.
extension UpdateGeometryArchivedCommand: FirestoreCommand {
    func apply(inFirestore ctx: FirestoreCommandContext) throws {
        // ------------- READS -----------------
        // check that target exists, otherwise abort (the command cannot be applied)
        guard try ctx.exists(.geometry(geometryId)) else {
            throw FirestoreCommandError.obsolete("geometry doesn't exist")
        }

        // ------------- WRITES ----------------
        ctx.updateData(
            [
                FirebaseGeometry.CodingKeys.archivedTimestamp.rawValue: archive
                    ? FieldValue.serverTimestamp()
                    : FieldValue.delete(),
            ],
            forDocument: .geometry(geometryId)
        )
    }
}
