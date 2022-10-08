import CoreLocation
import Foundation
import Kingfisher
import RealmSwift
import Turf

/// convenience function for generating new realm id
func generateRealmId() -> String {
    UUID().uuidString.lowercased()
}

// MARK: - run commands

/// ProjectModel extension for running commands
extension ProjectModel {
    func runCommands(_ commands: [Command]) async throws {
        // try to apply remotely
        if let remoteUpdater = remoteUpdater {
            try await remoteUpdater.runCommands(commands, writer: self)
        } else {
            // if remote not supported then try locally
            try await write { realm in
                try commands.forEach { try $0.apply(inRealm: realm) }
            }
        }
    }
}

// MARK: - commands

/// Implementation of higher level commands (composed of multiple `Command`s)
extension ProjectModel {
    /// Adds given photos to pending uploads and returns commands for:
    /// - creating the feature If geometry with given id has no feature
    /// - creating a collaboration If the feature has no collaboration
    /// - creating all new tags and an upload with given tags and description and adding it to a collaboration
    /// Throws error if geometry with given id not found.
    ///
    /// Marked with @MainActor as it needs to run on the main thread to have access to main thread realm objects (canvas)
    /// The write operation will be executed on a `writeRealm` so not on the main thread
    ///
    /// - Parameters:
    ///     - photosToAdd: the data for the images to add
    ///     - tags: array of tags, existing or new ones
    ///     - description: upload description
    ///     - geometryId: 'photoMarker' to add the upload to (to it's first feature/first collaboration)
    @MainActor
    func addPhotos(
        _ photosToAdd: [PhotoToAdd],
        tags: [TagViewModel],
        description: String,
        toCollaborationForGeometryId geometryId: String
    ) async throws -> [Command] {
        guard let geometry = mainRealm.object(ofType: Geometry.self, forPrimaryKey: geometryId) else {
            throw ModelError.geometryNotFound
        }

        for photoToAdd in photosToAdd {
            try await pendingUploadsModel.addPendingUpload(key: photoToAdd.cacheKey)
        }

        var commands: [Command] = []

        // create feature if geometry has no feature
        let featureId: String
        if let feature = geometry.features.first {
            featureId = feature.id
        } else {
            featureId = generateRealmId()
            commands.append(AddFeatureCommand(
                featureId: featureId,
                geometryId: geometryId,
                name: "",
                featureDescription: ""
            ))
        }

        // create collaboration if not there yet
        let collaborationId: String
        if let feature = geometry.features.first, let collaboration = feature.collaborations.first {
            collaborationId = collaboration.id
        } else {
            collaborationId = generateRealmId()
            let timestamp = photosToAdd.first?.timestamp ?? Date.now.timeIntervalSince1970
            commands.append(AddCollaborationCommand(
                collaborationId: collaborationId,
                featureId: featureId,
                authorId: userId,
                timestamp: timestamp,
                name: "",
                collaborationDescription: "",
                statusId: nil,
                tagIds: []
            ))
        }

        photosToAdd.forEach {
            commands.append(contentsOf: _addUpload(
                uploadId: $0.uploadId,
                timestamp: $0.timestamp,
                tags: tags,
                description: description,
                toCollaboration: collaborationId,
                imageHeightToWidth: $0.height2Width
            ))
        }
        return commands
    }

    /// Adds given photos to pending uploads and returns commands for:
    /// - creating a new geometry of photoMarker type and adding it to given canvas.
    /// - creating a feature attached to this geometry and the collaboration attached to the feature.
    /// - creating all new tags and an upload with given tags and description and adding it to a collaboration
    ///
    /// Marked with @MainActor as it needs to run on the main thread to have access to main thread realm objects (canvas)
    /// The write operation will be executed on a `writeRealm` so not on the main thread
    ///
    /// - Parameters:
    ///     - photosToAdd: the data for the images to add
    ///     - tags: array of tags, existing or new ones
    ///     - description: upload description
    ///     - coordinates: the coordinates for the photo marker
    ///     - canvas: should be from the `mainRealm`
    ///     - geometryId: this id will be used for the newly created geometry
    @MainActor
    func addPhotos(
        _ photosToAdd: [PhotoToAdd],
        tags: [TagViewModel],
        description: String,
        at coordinates: CLLocationCoordinate2D,
        in canvas: PDFCanvas,
        geometryId: String
    ) async throws -> [Command] {
        for photoToAdd in photosToAdd {
            try await pendingUploadsModel.addPendingUpload(key: photoToAdd.cacheKey)
        }

        let addGeometryCmd = AddGeometryCommand(
            geometryId: geometryId,
            canvasId: canvas.id,
            annotationType: .photoMarker,
            geometry: .point(Point(coordinates))
        )
        let addFeatureCmd = AddFeatureCommand(
            featureId: generateRealmId(),
            geometryId: addGeometryCmd.geometryId,
            name: "",
            featureDescription: nil
        )
        let timestamp = photosToAdd.first?.timestamp ?? Date.now.timeIntervalSince1970
        let addCollaborationCmd = AddCollaborationCommand(
            collaborationId: generateRealmId(),
            featureId: addFeatureCmd.featureId,
            authorId: userId,
            timestamp: timestamp,
            name: "",
            collaborationDescription: nil,
            statusId: nil,
            tagIds: []
        )
        var commands: [Command] = [addGeometryCmd, addFeatureCmd, addCollaborationCmd]
        photosToAdd.forEach {
            commands.append(contentsOf: _addUpload(
                uploadId: $0.uploadId,
                timestamp: $0.timestamp,
                tags: tags,
                description: description,
                toCollaboration: addCollaborationCmd.collaborationId,
                imageHeightToWidth: $0.height2Width
            ))
        }
        return commands
    }

    /// Returns commands for adding new upload with given tags (some of them may require creation) to collaboration with given id
    ///
    /// Marked with @MainActor as it needs to run on the main thread to have access to main thread realm objects (canvas)
    /// The write operation will be executed on a `writeRealm` so not on the main thread
    @MainActor
    func _addUpload(uploadId: String,
                    timestamp: TimeInterval,
                    tags: [TagViewModel],
                    description: String,
                    toCollaboration collaborationId: String,
                    imageHeightToWidth: Double) -> [Command]
    {
        var commands: [Command] = []

        // add all new tags
        commands.append(contentsOf: tags
            .filter(\.newTag)
            .map { AddTagCommand(tagId: $0.id, name: $0.name) })

        let addUploadCmd = AddUploadCommand(
            uploadId: uploadId,
            correlationId: uploadId,
            fileType: .image,
            parentType: "Collaboration",
            parentId: collaborationId,
            authorId: userId,
            timestamp: timestamp,
            name: nil,
            uploadDescription: description,
            url: nil,
            tagIds: tags.map(\.id),
            imageHeightToWidth: imageHeightToWidth
        )
        commands.append(addUploadCmd)

        return commands
    }

    /// Create commands for updating given Upload tags.
    /// The commands include creating new tags.
    func update(tags: [TagViewModel], forUpload upload: Upload) -> [Command] {
        var commands: [Command] = []

        // add all new tags
        commands.append(contentsOf: tags
            .filter(\.newTag)
            .map { AddTagCommand(tagId: $0.id, name: $0.name) })

        commands.append(UpdateUploadTagsCommand(uploadId: upload.id, tagIds: tags.map(\.id)))

        return commands
    }

    /// Create command for creating a new comment (or note if isNote = `true`) for given collaboration id.
    func addComment(commentText: String, isNote: Bool, toCollaboration collaborationId: String) -> [Command] {
        [
            AddCommentCommand(
                commentId: generateRealmId(),
                parentType: "Collaboration",
                parentId: collaborationId,
                authorId: userId,
                timestamp: Date.now.timeIntervalSince1970,
                text: commentText,
                textIsEdited: false,
                isNote: isNote
            ),
        ]
    }
}
