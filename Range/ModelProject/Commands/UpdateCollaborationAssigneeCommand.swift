import FirebaseFirestore
import Foundation
import RealmSwift

/// Update assignee for given Collaboration
struct UpdateCollaborationAssigneeCommand: Command, Codable, Equatable {
    var type: CommandType { .update } // don't make it a stored property, so it's not encoded
    var targetIds: Set<String> { .init([collaborationId]) }

    var authorId: String
    let collaborationId: String
    var assigneeId: String?
    /// Store update id for applying to Firestore (for idempotence we need to remember it and do not create multiple updates for this change)
    var updateId: String

    init(authorId: String, collaborationId: String, assigneeId: String?) {
        self.authorId = authorId
        self.collaborationId = collaborationId
        self.assigneeId = assigneeId
        updateId = generateRealmId()
    }
}

/// Update in local Realm db
extension UpdateCollaborationAssigneeCommand: LocalCommand {
    func apply(inRealm realm: Realm) throws {
        guard let collaboration = realm.object(ofType: Collaboration.self, forPrimaryKey: collaborationId) else {
            throw ModelError.collaborationNotFound
        }
        if let assigneeId = assigneeId {
            guard let user = realm.object(ofType: Participant.self, forPrimaryKey: assigneeId) else {
                throw ModelError.userNotFound
            }
            collaboration.assignee = user
        } else {
            collaboration.assignee = nil
        }
    }
}

/// Update `Collaboration.dueDateTimestamp` in Firestore.
extension UpdateCollaborationAssigneeCommand: FirestoreCommand {
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
        guard collaboration.assigneeId != assigneeId else {
            // do nothing, no change
            return
        }
        if let assigneeId = assigneeId {
            // if setting the assignee make sure the user exists
            guard try ctx.exists(.participant(assigneeId)) else {
                throw FirestoreCommandError.obsolete("assignee doesn't exist")
            }
        }

        // ------------- WRITES ----------------
        ctx.updateData(
            [FirestoreCollaboration.CodingKeys.assigneeId.rawValue: assigneeId != nil
                ? assigneeId!
                : FieldValue.delete()],
            forDocument: .collaboration(collaborationId)
        )
        try CreateUpdateCommand.addUpdate(
            updateId: updateId,
            parentId: collaborationId,
            parentType: "Collaboration",
            userId: authorId,
            field: .assignee,
            oldValue: collaboration.assigneeId != nil ? .string(collaboration.assigneeId!) : nil,
            newValue: assigneeId != nil ? .string(assigneeId!) : nil,
            inFirestore: ctx
        )
    }
}
