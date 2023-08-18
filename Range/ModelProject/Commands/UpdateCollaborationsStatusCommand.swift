import FirebaseFirestore
import Foundation
import RealmSwift

/// Update status for given Collaboration
struct UpdateCollaborationsStatusCommand: Command, Codable, Equatable {
    var type: CommandType { .update } // don't make it a stored property, so it's not encoded
    var targetIds: [String] { .init(collaborationIds) }

    var authorId: String
    let collaborationIds: [String]
    var statusId: String
    /// Store update id for applying to Firestore (for idempotence we need to remember it and do not create multiple updates for one name change)
    var updateIds: [String]

    init(authorId: String, collaborationIds: [String], statusId: String) {
        self.authorId = authorId
        self.collaborationIds = collaborationIds
        self.statusId = statusId
        updateIds = collaborationIds.map { _ in generateRealmId() }
    }
}

extension UpdateCollaborationsStatusCommand: LocalCommand {
    func apply(inRealm realm: Realm) throws {
        let collaborationsToUpdate = try collaborationIds.map {
            // fail locally if any of the object doesn't exist, this shouldn't really happen
            try realm.object(ofType: Collaboration.self, forPrimaryKey: $0).or(error: ModelError.collaborationNotFound)
        }
        guard let status = realm.object(ofType: Status.self, forPrimaryKey: statusId) else {
            throw ModelError.statusNotFound
        }
        collaborationsToUpdate.forEach { $0.status = status }
    }
}

/// Apply the `Collaboration.name` update in Firestore.
extension UpdateCollaborationsStatusCommand: FirestoreCommand {
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
        guard try ctx.exists(.statusName(statusId)) else {
            throw FirestoreCommandError.obsolete("status doesn't exist")
        }

        // ------------- WRITES ----------------
        for ((collaborationId, collaboration), updateId) in zip(collaborationsToUpdate, updateIds) {
            ctx.updateData(
                [FirestoreCollaboration.CodingKeys.statusId.rawValue: statusId],
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
}
