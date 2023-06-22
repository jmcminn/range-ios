import FirebaseFirestore
import Foundation
import RealmSwift

/// Update assignee for given Collaboration(s)
struct UpdateCollaborationsAssigneeCommand: Command, Codable, Equatable {
    var type: CommandType { .update } // don't make it a stored property, so it's not encoded
    var targetIds: Set<String> { .init(collaborationIds) }

    var authorId: String
    let collaborationIds: [String]
    var assigneeId: String?
    /// Store update id for applying to Firestore (for idempotence we need to remember it and do not create multiple updates for this change)
    var updateIds: [String]

    init(authorId: String, collaborationIds: [String], assigneeId: String?) {
        self.authorId = authorId
        self.collaborationIds = collaborationIds
        self.assigneeId = assigneeId
        updateIds = collaborationIds.map { _ in generateRealmId() }
    }
}

/// Update in local Realm db
extension UpdateCollaborationsAssigneeCommand: LocalCommand {
    func apply(inRealm realm: Realm) throws {
        let collaborationsToUpdate = try collaborationIds.map {
            // fail locally if any of the object doesn't exist, this shouldn't really happen
            try realm.object(ofType: Collaboration.self, forPrimaryKey: $0).or(error: ModelError.collaborationNotFound)
        }
        if let assigneeId = assigneeId {
            guard let user = realm.object(ofType: Participant.self, forPrimaryKey: assigneeId) else {
                throw ModelError.userNotFound
            }
            collaborationsToUpdate.forEach { $0.assignee = user }
        } else {
            collaborationsToUpdate.forEach { $0.assignee = nil }
        }
    }
}

/// Update `Collaboration.dueDateTimestamp` in Firestore.
extension UpdateCollaborationsAssigneeCommand: FirestoreCommand {
    func apply(inFirestore ctx: FirestoreCommandContext) throws {
        // ------------- READS -----------------
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
        if let assigneeId = assigneeId {
            // if setting the assignee make sure the user exists
            guard try ctx.exists(.participant(assigneeId)) else {
                throw FirestoreCommandError.obsolete("assignee doesn't exist")
            }
        }

        // ------------- WRITES ----------------
        for ((collaborationId, collaboration), updateId) in zip(collaborationsToUpdate, updateIds) {
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
}
