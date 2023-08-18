import FirebaseFirestore
import Foundation
import RealmSwift

/// Update dueDateTimestamp for given Collaboration(s)
struct UpdateCollaborationsDueDateCommand: Command, Codable, Equatable {
    var type: CommandType { .update } // don't make it a stored property, so it's not encoded
    var targetIds: [String] { .init(collaborationIds) }

    var authorId: String
    let collaborationIds: [String]
    var dueDateTimestamp: Date?
    /// Store update id for applying to Firestore (for idempotence we need to remember it and do not create multiple updates for this change)
    var updateIds: [String]

    init(authorId: String, collaborationIds: [String], dueDateTimestamp: Date?) {
        self.authorId = authorId
        self.collaborationIds = collaborationIds
        self.dueDateTimestamp = dueDateTimestamp
        updateIds = collaborationIds.map { _ in generateRealmId() }
    }
}

/// Update in local Realm db
extension UpdateCollaborationsDueDateCommand: LocalCommand {
    func apply(inRealm realm: Realm) throws {
        let collaborationsToUpdate = try collaborationIds.map {
            // fail locally if any of the object doesn't exist, this shouldn't really happen
            try realm.object(ofType: Collaboration.self, forPrimaryKey: $0).or(error: ModelError.collaborationNotFound)
        }
        collaborationsToUpdate.forEach { $0.dueDateTimestamp = dueDateTimestamp }
    }
}

/// Update `Collaboration.dueDateTimestamp` in Firestore.
extension UpdateCollaborationsDueDateCommand: FirestoreCommand {
    func apply(inFirestore ctx: FirestoreCommandContext) throws {
        // ------------- READS -----------------
        // check that target exists, otherwise abort (the command cannot be applied)
        let collaborationsToUpdate = try collaborationIds.compactMap { id in
            if let collaboration = try ctx.getDocument(.collaboration(id), as: FirestoreCollaboration.self) {
                // return a pair of (id, collab) as FirestoreCollaboration doesn't contain the id
                return (id, collaboration)
            } else {
                return nil
            }
        }
        if !collaborationIds.isEmpty, collaborationsToUpdate.isEmpty {
            throw FirestoreCommandError.obsolete("collaboration doesn't exist")
        }

        // ------------- WRITES ----------------
        for ((collaborationId, collaboration), updateId) in zip(collaborationsToUpdate, updateIds) {
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
                oldValue: collaboration
                    .dueDateTimestamp != nil ? .date(collaboration.dueDateTimestamp!.dateValue()) : nil,
                newValue: dueDateTimestamp != nil ? .date(dueDateTimestamp!) : nil,
                inFirestore: ctx
            )
        }
    }
}
