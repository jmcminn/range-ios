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
    var authorId: String
    var canvasId: String
    var geometryId: String
    var featureId: String // generated in init
    var collaborationId: String // generated in initializer
    var coordinates: LocationCoordinate2DCodable // no CLLocationCoordinate2D as it needs to be codable
    var tags: [CommandTag]
    var uploadDescription: String?
    var uploads: [CommandUpload]
    var statusId: String? // optional status to create a task collaboration

    init(
        authorId: String,
        canvasId: String,
        geometryId: String,
        featureId: String = generateRealmId(),
        collaborationId: String = generateRealmId(),
        coordinates: CLLocationCoordinate2D,
        tags: [CommandTag],
        uploadDescription: String?,
        uploads: [CommandUpload],
        statusId: String? = nil
    ) {
        self.authorId = authorId
        self.canvasId = canvasId
        self.geometryId = geometryId
        self.featureId = featureId
        self.collaborationId = collaborationId
        self.coordinates = .init(coordinates)
        self.tags = tags
        self.uploadDescription = uploadDescription
        self.uploads = uploads
        self.statusId = statusId
    }
}

/// Apply in local Realm db
extension CreateCollaborationCommand: LocalCommand {
    func apply(inRealm realm: Realm) throws {
        let canvas = try realm.object(ofType: PDFCanvas.self, forPrimaryKey: canvasId)
            .or(error: ModelError.canvasNotFound)
        let author = try realm.object(ofType: Participant.self, forPrimaryKey: authorId)
            .or(error: ModelError.userNotFound)

        let geometry = Geometry(
            id: geometryId,
            annotationType: .photoMarker,
            geometry: .point(Point(coordinates.decodedCoordinates))
        )
        realm.add(geometry, update: .modified)
        canvas.geometries.insert(geometry)

        let feature = Feature(id: featureId, name: "", description: nil)
        realm.add(feature, update: .modified)
        geometry.features.insert(feature)

        let collaboration = Collaboration(
            id: collaborationId,
            timestamp: Date.now,
            name: "",
            description: nil
        )
        realm.add(collaboration, update: .modified)
        collaboration.author = author
        feature.collaborations.insert(collaboration)

        // add or update tags
        let tags = tags.map(\.asTag)
        tags.forEach { realm.add($0, update: .modified) }

        uploads.forEach {
            let upload = Upload(
                id: $0.id,
                timestamp: Date.now,
                name: nil,
                description: uploadDescription,
                correlationId: $0.id,
                fileType: .image,
                imageHeightToWidth: $0.imageHeightToWidth
            )
            upload.author = author
            // add new upload
            realm.add(upload, update: .error)
            upload.tags.append(objectsIn: tags)
            tags.forEach { t in t.uploads.insert(upload) }
            collaboration.uploads.insert(upload)
        }

        if let statusId = statusId {
            collaboration.status = try realm.object(ofType: Status.self, forPrimaryKey: statusId)
                .or(error: ModelError.statusNotFound)
        }
    }
}

/// Creates new Geometry, Feature, Collaboration in Firestore. Create Uploads and adds to collaboration.
/// Creates the tags that don't exist yet.
/// This command is idempotent in a way that it checks if given geometry, feature, collaboration, uploads or tags are already created,
/// if so it doesn't recreate or update them.
/// It fails with the "obsolete" error if canvas or author doesn't exist. This means that either of them was already removed
/// and this command should be aborted and not attempted again.
extension CreateCollaborationCommand: FirestoreCommand {
    func apply(inFirestore ctx: FirestoreCommandContext) throws {
        // ------------- READS -----------------
        // check that collaboration and author exist, otherwise abort (the command cannot be applied)
        guard try ctx.exists(.canvas(canvasId)) else {
            throw FirestoreCommandError.obsolete("canvas doesn't exist")
        }
        guard try ctx.exists(.participant(authorId)) else {
            throw FirestoreCommandError.obsolete("user doesn't exist")
        }
        let createGeometry = try !ctx.exists(.geometry(geometryId))
        let createFeature = try !ctx.exists(.feature(featureId))
        let createCollaboration = try !ctx.exists(.collaboration(collaborationId))

        // only add new tags... don't touch the existing ones
        let newTags = try tags.filter { try !ctx.exists(.tagName($0.id)) }

        // make it idempotent, only upload if not uploaded yet (this check is too granular, as
        // if any upload is there it means all are there but still it's correct)
        let newUploads = try uploads.filter { try !ctx.exists(.upload($0.id)) }

        // ------------- WRITES ----------------
        if createGeometry {
            let firestoreGeometry = FirestoreGeometry(
                canvasId: canvasId,
                geometry: .point(Point(coordinates.decodedCoordinates))
            )
            try ctx.setData(from: firestoreGeometry, forDocument: .geometry(geometryId))
        }
        if createFeature {
            let firestoreFeature = FirestoreFeature(geometryId: geometryId, name: "", description: nil)
            try ctx.setData(from: firestoreFeature, forDocument: .feature(featureId))
        }
        if createCollaboration {
            let firestoreObject = FirestoreCollaboration(
                featureId: featureId,
                authorId: authorId,
                timestamp: Timestamp(),
                statusId: statusId,
                name: "",
                collaborationDescription: nil,
                tagIds: [],
                assigneeId: nil,
                dueDateTimestamp: nil
            )
            var data = try Firestore.Encoder().encode(firestoreObject)
            data[FirestoreUpdate.CodingKeys.timestamp.rawValue] = FieldValue.serverTimestamp()
            ctx.setData(data, forDocument: .collaboration(collaborationId))
        }
        try newTags.forEach {
            try ctx.setData(from: $0.asFirestoreTagName, forDocument: .tagName($0.id))
        }

        let tagIds = tags.map(\.id)
        // add uploads
        try newUploads.forEach {
            let firestoreObject = FirestoreUpload(
                parentId: collaborationId,
                parentType: "Collaboration",
                authorId: authorId,
                timestamp: Timestamp(), // doesn't matter, updated to server timestamp after encoding
                name: nil,
                uploadDescription: uploadDescription,
                correlationId: $0.id,
                tagIds: tagIds,
                fileTypeString: Upload.FileType.image.rawValue,
                imageHeightToWidth: $0.imageHeightToWidth
            )
            var data = try Firestore.Encoder().encode(firestoreObject)
            data[FirestoreUpdate.CodingKeys.timestamp.rawValue] = FieldValue.serverTimestamp()
            ctx.setData(data, forDocument: .upload($0.id))
        }
    }
}
