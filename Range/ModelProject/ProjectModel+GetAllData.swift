import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseFunctions
import FirebaseSharedSwift
import Foundation
import OSLog
import RealmSwift

extension ProjectModel {
    // Call getAllDataForProject and apply the result to local database.
    // If this is the first call (there's no ProjectMetadata.feedLastUpdatedTimestamp) the call
    // will replace the database contents with the contents receivec from backend (as it's a full result)
    // If there's a subsequent call, it'll only fetch the data since ProjectMetadata.feedLastUpdatedTimestamp
    // and apply the delta to the local database
    //
    // Returns the feedLastUpdatedTimestamp after fetch - all data until this timestamp is in the local DB.
    public func getAllData() async throws -> Date {
        var feedLastUpdatedTimestamp: Date?
        writeQueue.sync {
            feedLastUpdatedTimestamp = writeRealm.object(
                ofType: ProjectMetadata.self,
                forPrimaryKey: ProjectMetadata.metadataId
            )?.feedLastUpdatedTimestamp
        }

        let result = try await makeGetAllDataCall(since: feedLastUpdatedTimestamp)

        guard let resultData = result.data as? [String: Any],
              let data = resultData["data"] as? [String: [[String: Any]]],
              let metadata = resultData["metadata"] as? [String: Any],
              let timestampInt = metadata["timestamp"] as? Int
        else {
            Logger.model.error("Unexpected result from getAllDataForProject: \(result)")
            throw "Unexpected result from getAllDataForProject: \(result)"
        }

        let timestamp = Date(timeIntervalSince1970: TimeInterval(timestampInt) / 1000.0)

        // The full fetch is when there's no since parameter provided to getAllDataForProject.
        // Also when asked for delta since timestamp the backend may have decided that it'll give a full set
        // because the changeset is too big (like if the user for downgraded to a Guest for example)
        // So the full data set is indicated by the lack of `since` in the response metadata
        // If this is a full fetch then we replace the db contents.
        let responseSince = metadata["since"] as? Int
        let replace = responseSince == nil
        try await storeGetAllDataResults(
            timestamp: timestamp,
            data: data,
            deleted: resultData["deleted"] as? [String: [String]],
            replace: replace
        )
        return timestamp
    }

    private func makeGetAllDataCall(since: Date?) async throws -> HTTPSCallableResult {
        try await Functions.functions(region: "us-west2")
            .httpsCallable("getAllDataForProject")
            .call([
                "projectId": projectId,
                "since": since.map { Int($0.timeIntervalSince1970 * 1000) } as Any,
                "selectedFields": [
                    "geometries": FirestoreGeometry.CodingKeys.allCases.map(\.stringValue),
                    "collaborations": FirestoreCollaboration.CodingKeys.allCases.map(\.stringValue),
                    "updates": FirestoreUpdate.CodingKeys.allCases.map(\.stringValue),
                    "uploads": FirestoreUpload.CodingKeys.allCases.map(\.stringValue),
                    "comments": FirestoreComment.CodingKeys.allCases.map(\.stringValue),
                ],
            ])
    }

    // write all the changes in one transaction. This makes
    // it much faster when getting the initial data with all the documents
    private func storeGetAllDataResults(
        timestamp: Date,
        data: [String: [[String: Any]]],
        deleted: [String: [String]]?,
        replace: Bool
    ) async throws {
        let decoder = FirebaseDataDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        try await write { realm in
            realm.add(
                ProjectMetadata(feedLastUpdatedTimestamp: timestamp),
                update: .modified
            )

            self.upsertObjects(data["geometries"], as: FirestoreGeometry.self, inRealm: realm, replace: replace)
            self.upsertObjects(
                data["collaborations"],
                as: FirestoreCollaboration.self,
                inRealm: realm,
                replace: replace
            )
            self.upsertObjects(data["updates"], as: FirestoreUpdate.self, inRealm: realm, replace: replace)
            self.upsertObjects(data["uploads"], as: FirestoreUpload.self, inRealm: realm, replace: replace)
            self.upsertObjects(data["comments"], as: FirestoreComment.self, inRealm: realm, replace: replace)

            if let deleted {
                self.deleteLocalCollaborations(deleted["collaborationIds"], inRealm: realm)
                self.deleteLocalComments(deleted["commentIds"], inRealm: realm)
                self.deleteLocalUploads(deleted["uploadIds"], inRealm: realm)
            }
        }
    }

    func deleteLocalCollaborations(_ ids: [String]?, inRealm realm: Realm) {
        guard let ids else { return }
        for id in ids {
            do {
                try DeleteCollaborationCommand(collaborationId: id).apply(inRealm: realm)
            } catch {
                Logger.model.warning("Error deleting local object with id \(id): \(error.localizedDescription)")
            }
        }
    }

    func deleteLocalComments(_ ids: [String]?, inRealm realm: Realm) {
        guard let ids else { return }
        for id in ids {
            do {
                try DeleteCommentCommand(commentId: id).apply(inRealm: realm)
            } catch {
                Logger.model.warning("Error deleting local object with id \(id): \(error.localizedDescription)")
            }
        }
    }

    func deleteLocalUploads(_ ids: [String]?, inRealm realm: Realm) {
        guard let ids else { return }
        for id in ids {
            do {
                try DeleteUploadCommand(uploadId: id).apply(inRealm: realm)
            } catch {
                Logger.model.warning("Error deleting local object with id \(id): \(error.localizedDescription)")
            }
        }
    }
}
