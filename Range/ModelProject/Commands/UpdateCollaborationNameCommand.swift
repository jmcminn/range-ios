import FirebaseFirestore
import Foundation
import RealmSwift

/// Update name for given Collaboration
struct UpdateCollaborationNameCommand: Command, Codable, Equatable {
    var type: CommandType { .update } // don't make it a stored property, so it's not encoded
    var targetIds: [String] { .init([collaborationId]) }

    var authorId: String
    let collaborationId: String
    var name: String
    /// Store update id for applying to Firestore (for idempotence we need to remember it and do not create multiple updates for one name change)
    var updateId: String

    init(authorId: String, collaborationId: String, name: String) {
        self.authorId = authorId
        self.collaborationId = collaborationId
        self.name = name
        updateId = generateRealmId()
    }
}

extension UpdateCollaborationNameCommand: LocalCommand {
    func apply(inRealm realm: Realm) throws {
        guard let collaboration = realm.object(ofType: Collaboration.self, forPrimaryKey: collaborationId) else {
            throw ModelError.collaborationNotFound
        }
        collaboration.name = name
    }
}

/// Apply the `Collaboration.name` update in Firestore.
extension UpdateCollaborationNameCommand: FirestoreCommand {
    func apply(inFirestore ctx: FirestoreCommandContext) throws {
        // ------------- READS -----------------
        guard try !ctx.exists(.update(updateId)) else {
            // do nothing if it's already applied (assume it's applied if the Update exists...)
            return
        }
        // check that target exists, otherwise abort (the command cannot be applied)
        guard let collaboration = try ctx.getDocument(.collaboration(collaborationId), as: FirestoreCollaboration.self)
        else {
            throw FirestoreCommandError.obsolete("collaboration doesn't exist")
        }
        guard collaboration.name != name else {
            // do nothing, the name is not really different...
            return
        }

        // ------------- WRITES ----------------
        ctx.updateData(
            [FirestoreCollaboration.CodingKeys.name.rawValue: name],
            forDocument: .collaboration(collaborationId)
        )
        try CreateUpdateCommand.addUpdate(
            updateId: updateId,
            parentId: collaborationId,
            parentType: "Collaboration",
            userId: authorId,
            field: .name,
            oldValue: .string(collaboration.name),
            newValue: .string(name),
            inFirestore: ctx
        )
    }
}
