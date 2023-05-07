import FirebaseFirestore
import Foundation
import RealmSwift

/// Update description for given Collaboration
struct UpdateCollaborationDescriptionCommand: Command, Codable, Equatable {
    var type: CommandType { .update } // don't make it a stored property, so it's not encoded
    var targetIds: Set<String> { .init([collaborationId]) }

    var authorId: String
    let collaborationId: String
    var collaborationDescription: String?
    /// Store update id for applying to Firestore (for idempotence we need to remember it and do not create multiple updates for one change)
    var updateId: String

    init(authorId: String, collaborationId: String, description: String?) {
        self.authorId = authorId
        self.collaborationId = collaborationId
        collaborationDescription = description
        updateId = generateRealmId()
    }
}

extension UpdateCollaborationDescriptionCommand: LocalCommand {
    func apply(inRealm realm: Realm) throws {
        guard let collaboration = realm.object(ofType: Collaboration.self, forPrimaryKey: collaborationId) else {
            throw ModelError.collaborationNotFound
        }
        collaboration.collaborationDescription = collaborationDescription
    }
}

/// Apply the update in Firestore.
extension UpdateCollaborationDescriptionCommand: FirestoreCommand {
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
        guard collaboration.collaborationDescription != collaborationDescription else {
            // do nothing, the name is not really different...
            return
        }

        // ------------- WRITES ----------------
        ctx.updateData(
            [FirestoreCollaboration.CodingKeys.collaborationDescription.rawValue: collaborationDescription != nil
                ? collaborationDescription!
                : FieldValue.delete()],
            forDocument: .collaboration(collaborationId)
        )
        try CreateUpdateCommand.addUpdate(
            updateId: updateId,
            parentId: collaborationId,
            parentType: "Collaboration",
            userId: authorId,
            field: .description,
            oldValue: collaboration
                .collaborationDescription != nil ? .string(collaboration.collaborationDescription!) : nil,
            newValue: collaborationDescription != nil ? .string(collaborationDescription!) : nil,
            inFirestore: ctx
        )
    }
}
