import FirebaseFirestore
import Foundation
import RealmSwift

/// Update archivedTimestamp for geometry(ies)
struct UpdateGeometriesArchivedCommand: Command, Codable, Equatable {
    var type: CommandType { .update } // don't make it a stored property, so it's not encoded
    var targetIds: [String] { .init(geometryIds) }

    let geometryIds: [String]
    var archive: Bool
}

extension UpdateGeometriesArchivedCommand: LocalCommand {
    func apply(inRealm realm: Realm) throws {
        let geometriesToUpdate = try geometryIds.map {
            // fail locally if any of the object doesn't exist, this shouldn't really happen
            try realm.object(ofType: Geometry.self, forPrimaryKey: $0).or(error: ModelError.geometryNotFound)
        }
        geometriesToUpdate.forEach { $0.archivedTimestamp = archive ? Date.now : nil }
    }
}

/// Apply the `Comment` update in Firestore.
extension UpdateGeometriesArchivedCommand: FirestoreCommand {
    func apply(inFirestore ctx: FirestoreCommandContext) throws {
        // ------------- READS -----------------
        // check that target exists, otherwise abort (the command cannot be applied)
        let geometriesToUpdate = try geometryIds.filter { try ctx.exists(.geometry($0)) }
        if !geometryIds.isEmpty, geometriesToUpdate.isEmpty {
            throw FirestoreCommandError.obsolete("geometry doesn't exist")
        }

        // ------------- WRITES ----------------
        for geometryId in geometriesToUpdate {
            ctx.updateData(
                [
                    FirestoreGeometry.CodingKeys.archivedTimestamp.rawValue: archive
                        ? FieldValue.serverTimestamp()
                        : FieldValue.delete(),
                ],
                forDocument: .geometry(geometryId)
            )
        }
    }
}
