import CoreLocation
import FirebaseFirestore
import Foundation
import RealmSwift
import Turf

/// Creates geometry, feature and collaboration.
/// Adds given uploads to collaboration.
/// Creates tags if not existing yet.
/// Attach provided tags to all uploads.
struct CreateCollaborationCommand: Command, Codable, Equatable {
    var operations: [CommandOperationType: [String]] {
        let createdIds: [String] =
            [geometryId, featureId, collaborationId] +
            uploads.map(\.mediaKey.uploadId) +
            (tags + uploadTags).compactMap { $0.isNew ? $0.id : nil }
        return [.create: createdIds]
    }

    var authorId: String
    var canvasId: String
    var geometryId: String
    var featureId: String // generated in init, still expected by backend but not needed locally
    var collaborationId: String // generated in initializer
    var coordinates: LocationCoordinate2DCodable // no CLLocationCoordinate2D as it needs to be codable
    var statusId: String? // optional status to create a task collaboration
    var categoryId: String?
    var name: String?
    var collaborationDescription: String?
    var assigneeId: String?
    var dueDateTimestamp: Date?
    var tags: [CommandTag]
    var followerIds: [String]
    var uploadTags: [CommandTag]
    var uploadDescription: String?
    var uploads: [CommandUpload]

    init(
        authorId: String,
        canvasId: String,
        geometryId: String,
        featureId: String = generateRealmId(),
        collaborationId: String = generateRealmId(),
        coordinates: CLLocationCoordinate2D,
        statusId: String? = nil,
        categoryId: String? = nil,
        name: String? = nil,
        collaborationDescription: String? = nil,
        assigneeId: String? = nil,
        dueDateTimestamp: Date? = nil,
        tags: [CommandTag] = [],
        followerIds: [String] = [],
        uploadTags: [CommandTag] = [],
        uploadDescription: String? = nil,
        uploads: [CommandUpload] = []
    ) {
        self.authorId = authorId
        self.canvasId = canvasId
        self.geometryId = geometryId
        self.featureId = featureId
        self.collaborationId = collaborationId
        self.coordinates = .init(coordinates)
        self.statusId = statusId
        self.categoryId = categoryId
        self.name = name
        self.collaborationDescription = collaborationDescription
        self.assigneeId = assigneeId
        self.dueDateTimestamp = dueDateTimestamp
        self.tags = tags
        self.followerIds = followerIds
        self.uploadTags = uploadTags
        self.uploadDescription = uploadDescription
        self.uploads = uploads
    }
}

/// Apply in local Realm db
extension CreateCollaborationCommand: LocalCommand {
    func apply(inRealm realm: Realm) throws {
        let canvas = try realm.object(ofType: Canvas.self, forPrimaryKey: canvasId)
            .or(error: ModelError.canvasNotFound)
        let author = try realm.object(ofType: Participant.self, forPrimaryKey: authorId)
            .or(error: ModelError.userNotFound)
        let assignee: Participant?
        if let assigneeId = assigneeId {
            assignee = try realm.object(ofType: Participant.self, forPrimaryKey: assigneeId)
                .or(error: ModelError.userNotFound)
        } else {
            assignee = nil
        }
        let followers = try followerIds.map { id in
            try realm.object(ofType: Participant.self, forPrimaryKey: id).or(error: ModelError.userNotFound)
        }

        let geometry = Geometry(
            id: geometryId,
            annotationType: .photoMarker,
            geometry: .point(Point(coordinates.decodedCoordinates))
        )
        realm.add(geometry, update: .modified)
        canvas.geometries.insert(geometry)

        let collaboration = Collaboration(
            id: collaborationId,
            createdAt: Date.now,
            lastUpdatedAt: Date.now,
            name: name ?? "",
            description: collaborationDescription,
            dueDateTimestamp: dueDateTimestamp
        )
        realm.add(collaboration, update: .modified)
        collaboration.author = author
        collaboration.assignee = assignee
        geometry.collaborations.insert(collaboration)
        let tags = tags.map(\.asTag)
        tags.forEach { realm.add($0, update: .modified) }
        collaboration.tags.append(objectsIn: tags)
        tags.forEach { t in t.collaborations.insert(collaboration) }

        collaboration.followers.append(objectsIn: followers)

        // add or update tags
        let uploadTags = uploadTags.map(\.asTag)
        uploadTags.forEach { realm.add($0, update: .modified) }

        uploads.forEach {
            let localStorageVersion = Map<String, String>()
            // mark storage version that there is a local file, so the MediaKey for MediaCache can
            // be constructed properly
            // After the file is uploaded this will be replaced with the real storage version from
            // backend. Pending uploads wait for the Upload object to be created (fail while it's not there)
            // so it's guaranteed that this will be set BEFORE the real value.
            localStorageVersion.setMainToLocalFile(annotated: false, generation: $0.mediaKey.storageVersion)
            if let annotatedMediaKey = $0.annotatedMediaKey {
                localStorageVersion.setMainToLocalFile(annotated: true, generation: annotatedMediaKey.storageVersion)
            }
            let upload = Upload(
                id: $0.mediaKey.uploadId,
                createdAt: Date.now,
                lastUpdatedAt: Date.now,
                name: $0.name,
                description: uploadDescription,
                correlationId: $0.mediaKey.uploadId,
                fileType: .jpeg,
                imageHeightToWidth: $0.imageHeightToWidth,
                fileSize: $0.fileSize,
                localStorageVersion: localStorageVersion,
                annotations: $0.annotations
            )
            upload.author = author
            // add new upload
            realm.add(upload, update: .error)
            upload.tags.append(objectsIn: uploadTags)
            uploadTags.forEach { t in t.uploads.insert(upload) }
            collaboration.uploads.insert(upload)
        }

        if let statusId {
            collaboration.status = try realm.object(ofType: Status.self, forPrimaryKey: statusId)
                .or(error: ModelError.statusNotFound)
        }
        if let categoryId {
            collaboration.category = try realm.object(ofType: Category.self, forPrimaryKey: categoryId)
                .or(error: ModelError.categoryNotFound)
        }
    }
}

/// Add pending uploads for all the media keys
extension CreateCollaborationCommand: PendingUploadCommand {
    func addPendingUploads(_ pendingUploadsModel: PendingUploadsModel) async throws {
        for upload in uploads {
            try await pendingUploadsModel.addPendingUpload(forKey: upload.mediaKey)
            if let annotatedMediaKey = upload.annotatedMediaKey {
                try await pendingUploadsModel.addPendingUpload(forKey: annotatedMediaKey)
            }
        }
    }
}

/// Provide data for 'createCollaboration' firebase function call
extension CreateCollaborationCommand: FirebaseFunctionCommand {
    var functionName: String { "createCollaboration" }

    var functionData: [String: Any?]? {
        var data = [
            "canvasId": canvasId,
            "geometryId": geometryId,
            "featureId": featureId,
            "collaborationId": collaborationId,
            "coordinates": [coordinates.longitude, coordinates.latitude],
            "name": name ?? "",
            "description": collaborationDescription as Any,
            "assigneeId": assigneeId as Any,
            "statusId": statusId as Any,
            "dueDateTimestamp": dueDateTimestamp.map { Int($0.timeIntervalSince1970 * 1000) } as Any,
            "tags": tags.map { ["id": $0.id, "name": $0.name] },
            "followers": followerIds,
            "uploads": uploads.map { [
                "id": $0.mediaKey.uploadId,
                "fileType": $0.mediaKey.fileType.rawValue,
                "fileSize": $0.fileSize,
                "imageHeightToWidth": $0.imageHeightToWidth as Any,
                "name": $0.name as Any,
                "description": uploadDescription as Any,
                "tags": uploadTags.map { uploadTag in ["id": uploadTag.id, "name": uploadTag.name] },
                "annotations": $0.annotations?.persistableValue as Any,
            ] },
        ]
        if let categoryId {
            data["categoryId"] = categoryId
        }
        return data
    }
}
