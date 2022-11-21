import FirebaseFirestore
import Foundation
import RealmSwift

/// Update status for given Collaboration
struct UpdateCollaborationStatusCommand: Command, Codable, Equatable {
    var authorId: String
    let collaborationId: String
    var statusId: String
    /// Store update id for applying to Firestore (for idempotence we need to remember it and do not create multiple updates for one name change)
    var updateId: String

    init(authorId: String, collaborationId: String, statusId: String) {
        self.authorId = authorId
        self.collaborationId = collaborationId
        self.statusId = statusId
        updateId = generateRealmId()
    }
}

extension UpdateCollaborationStatusCommand: LocalCommand {
    func apply(inRealm realm: Realm) throws {
        guard let collaboration = realm.object(ofType: Collaboration.self, forPrimaryKey: collaborationId) else {
            throw ModelError.collaborationNotFound
        }
        guard let status = realm.object(ofType: Status.self, forPrimaryKey: statusId) else {
            throw ModelError.statusNotFound
        }
        collaboration.status = status
    }
}

/// Apply the `Collaboration.name` update in Firestore.
extension UpdateCollaborationStatusCommand: FirestoreCommand {
    func apply(inFirestore ctx: FirestoreCommandContext) throws {
        // ------------- READS -----------------
        guard try !ctx.exists(.update(updateId)) else {
            // do nothing if it's already applied (assume it's applied if the Update exists...)
            return
        }
        // check that target exists, otherwise abort (the command cannot be applied)
        guard let collaboration = try ctx.getDocument(.collaboration(collaborationId), as: FirebaseCollaboration.self)
        else {
            throw FirestoreCommandError.obsolete("collaboration doesn't exist")
        }
        guard try ctx.exists(.statusName(statusId)) else {
            throw FirestoreCommandError.obsolete("status doesn't exist")
        }
        guard collaboration.statusId != statusId else {
            // do nothing, the status is the same
            return
        }

        // ------------- WRITES ----------------
        ctx.updateData(
            [FirebaseCollaboration.CodingKeys.statusId.rawValue: statusId],
            forDocument: .collaboration(collaborationId)
        )
        try CreateUpdateCommand.addUpdate(
            updateId: updateId,
            parentId: collaborationId,
            parentType: "Collaboration",
            userId: authorId,
            field: .statusName,
            oldValue: collaboration.statusId != nil ? .string(collaboration.statusId!) : nil,
            newValue: .string(statusId),
            inFirestore: ctx
        )
    }
}
