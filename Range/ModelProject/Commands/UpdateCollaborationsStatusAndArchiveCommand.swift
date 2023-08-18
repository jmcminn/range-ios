import FirebaseFirestore
import Foundation
import RealmSwift

/// Update status for given Collaboration(s) and mark Geometry(ies) as archived
struct UpdateCollaborationsStatusAndArchiveCommand: Command, Codable, Equatable {
    var type: CommandType { .update } // don't make it a stored property, so it's not encoded
    var targetIds: [String] { .init(geometryIds + collaborationIds) }

    var authorId: String
    let geometryIds: [String]
    let collaborationIds: [String]
    var statusId: String
    /// Store update id for applying to Firestore (for idempotence we need to remember it and do not create multiple updates for one name change)
    var updateIds: [String]

    init(authorId: String, geometryIds: [String], collaborationIds: [String], statusId: String) {
        self.authorId = authorId
        self.geometryIds = geometryIds
        self.collaborationIds = collaborationIds
        self.statusId = statusId
        updateIds = collaborationIds.map { _ in generateRealmId() }
    }
}

extension UpdateCollaborationsStatusAndArchiveCommand: LocalCommand {
    func apply(inRealm realm: Realm) throws {
        let collaborationsToUpdate = try collaborationIds.map {
            // fail locally if any of the object doesn't exist, this shouldn't really happen
            try realm.object(ofType: Collaboration.self, forPrimaryKey: $0).or(error: ModelError.collaborationNotFound)
        }
        let geometriesToUpdate = try geometryIds.map {
            // fail locally if any of the object doesn't exist, this shouldn't really happen
            try realm.object(ofType: Geometry.self, forPrimaryKey: $0).or(error: ModelError.geometryNotFound)
        }
        guard let status = realm.object(ofType: Status.self, forPrimaryKey: statusId) else {
            throw ModelError.statusNotFound
        }
        collaborationsToUpdate.forEach { $0.status = status }
        geometriesToUpdate.forEach { $0.archivedTimestamp = Date.now }
    }
}

/// Apply the `Collaboration.name` update in Firestore.
extension UpdateCollaborationsStatusAndArchiveCommand: FirestoreCommand {
    func apply(inFirestore ctx: FirestoreCommandContext) throws {
        // ------------- READS -----------------
        let collaborationsToUpdate = try getCollaborationsToUpdate(ctx)
        guard try ctx.exists(.statusName(statusId)) else {
            throw FirestoreCommandError.obsolete("status doesn't exist")
        }
        let geometriesToUpdate = try getGeometriesToUpdate(ctx)

        // ------------- WRITES ----------------
        try updateCollaborations(ctx, collaborations: collaborationsToUpdate)
        updateGeometries(ctx, geometriesToUpdate)
    }

    /// Returns an array of existing collaboration as (id, collab) pairs as FirestoreCollaboration doesn't contain the id
    private func getCollaborationsToUpdate(_ ctx: FirestoreCommandContext) throws
        -> [(String, FirestoreCollaboration)]
    {
        let collaborationsToUpdate = try collaborationIds.compactMap { id in
            if let collaboration = try ctx.getDocument(.collaboration(id), as: FirestoreCollaboration.self) {
                return (id, collaboration)
            } else {
                return nil
            }
        }
        if !collaborationIds.isEmpty, collaborationsToUpdate.isEmpty {
            throw FirestoreCommandError.obsolete("collaboration doesn't exist")
        }
        return collaborationsToUpdate
    }

    private func updateCollaborations(
        _ ctx: FirestoreCommandContext,
        collaborations: [(String, FirestoreCollaboration)]
    ) throws {
        for ((collaborationId, collaboration), updateId) in zip(collaborations, updateIds) {
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

    /// Returns array of existing geometries to update
    private func getGeometriesToUpdate(_ ctx: FirestoreCommandContext) throws -> [String] {
        let geometriesToUpdate = try geometryIds.filter { try ctx.exists(.geometry($0)) }
        if !geometryIds.isEmpty, geometriesToUpdate.isEmpty {
            throw FirestoreCommandError.obsolete("geometry doesn't exist")
        }
        return geometriesToUpdate
    }

    private func updateGeometries(_ ctx: FirestoreCommandContext, _ geometries: [String]) {
        for geometryId in geometries {
            ctx.updateData(
                [
                    FirestoreGeometry.CodingKeys.archivedTimestamp.rawValue: FieldValue.serverTimestamp(),
                ],
                forDocument: .geometry(geometryId)
            )
        }
    }
}
