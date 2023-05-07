import FirebaseFirestore
import Foundation
import RealmSwift

/// Update dueDateTimestamp for given Collaboration
struct UpdateCollaborationDueDateCommand: Command, Codable, Equatable {
    var type: CommandType { .update } // don't make it a stored property, so it's not encoded
    var targetIds: Set<String> { .init([collaborationId]) }

    var authorId: String
    let collaborationId: String
    var dueDateTimestamp: Date?
    /// Store update id for applying to Firestore (for idempotence we need to remember it and do not create multiple updates for this change)
    var updateId: String

    init(authorId: String, collaborationId: String, dueDateTimestamp: Date?) {
        self.authorId = authorId
        self.collaborationId = collaborationId
        self.dueDateTimestamp = dueDateTimestamp
        updateId = generateRealmId()
    }
}

/// Update in local Realm db
extension UpdateCollaborationDueDateCommand: LocalCommand {
    func apply(inRealm realm: Realm) throws {
        guard let collaboration = realm.object(ofType: Collaboration.self, forPrimaryKey: collaborationId) else {
            throw ModelError.collaborationNotFound
        }
        collaboration.dueDateTimestamp = dueDateTimestamp
    }
}

/// Update `Collaboration.dueDateTimestamp` in Firestore.
extension UpdateCollaborationDueDateCommand: FirestoreCommand {
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
        guard collaboration.dueDateTimestamp?.dateValue() != dueDateTimestamp else {
            // do nothing, the name is not really different...
            return
        }

        // ------------- WRITES ----------------
        ctx.updateData(
            [FirestoreCollaboration.CodingKeys.dueDateTimestamp.rawValue: dueDateTimestamp != nil
                ? Timestamp(date: dueDateTimestamp!)
                : FieldValue.delete()],
            forDocument: .collaboration(collaborationId)
        )
        try CreateUpdateCommand.addUpdate(
            updateId: updateId,
            parentId: collaborationId,
            parentType: "Collaboration",
            userId: authorId,
            field: .dueDateTimestamp,
            oldValue: collaboration.dueDateTimestamp != nil ? .date(collaboration.dueDateTimestamp!.dateValue()) : nil,
            newValue: dueDateTimestamp != nil ? .date(dueDateTimestamp!) : nil,
            inFirestore: ctx
        )
    }
}
