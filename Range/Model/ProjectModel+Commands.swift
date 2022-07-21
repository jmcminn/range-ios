import CoreLocation
import Foundation
import Kingfisher
import RealmSwift
import Turf

/// convenience function for generating new realm id
func generateRealmId() -> String {
    UUID().uuidString.lowercased()
}

/// ProjectModel extension for running commands
extension ProjectModel {
    /// Returns commands for:
    /// - creating the feature If geometry with given id has no feature
    /// - creating a collaboration If the feature has no collaboration
    /// - creating all new tags and an upload with given tags and description and adding it to a collaboration
    /// Throws error if geometry with given id not found.
    ///
    /// - Parameters:
    ///     - imageData: the data for the image
    ///     - tags: array of tags, existing or new ones
    ///     - description: upload description
    ///     - geometryId: 'photoMarker' to add the upload to (to it's first feature/first collaboration)
    func addPhoto(
        _ imageData: Data,
        tags: [TagViewModel],
        description: String,
        toCollaborationForGeometryId geometryId: String
    ) throws -> [Command] {
        guard let geometry = mainRealm.object(ofType: Geometry.self, forPrimaryKey: geometryId) else {
            throw ModelError.geometryNotFound
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
            commands.append(AddCollaborationCommand(
                collaborationId: collaborationId,
                featureId: featureId,
                name: "",
                collaborationDescription: "",
                statusId: nil,
                tagIds: []
            ))
        }

        commands.append(contentsOf: _addPhoto(imageData, tags: tags, description: description,
                                              toCollaboration: collaborationId))
        return commands
    }

    /// Returns commands for
    /// - creating a new geometry of photoMarker type and adding it to given canvas.
    /// - creating a feature attached to this geometry and the collaboration attached to the feature.
    /// - creating all new tags and an upload with given tags and description and adding it to a collaboration
    ///
    /// - Parameters:
    ///     - imageData: the data for the image
    ///     - tags: array of tags, existing or new ones
    ///     - description: upload description
    ///     - coordinates: the coordinates for the photo marker
    ///     - canvas: should be from the `mainRealm`
    ///     - geometryId: this id will be used for the newly created geometry
    func addPhoto(
        _ imageData: Data,
        tags: [TagViewModel],
        description: String,
        at coordinates: CLLocationCoordinate2D,
        in canvas: PDFCanvas,
        geometryId: String
    ) -> [Command] {
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
            featureDescription: ""
        )
        let addCollaborationCmd = AddCollaborationCommand(
            collaborationId: generateRealmId(),
            featureId: addFeatureCmd.featureId,
            name: "",
            collaborationDescription: "",
            statusId: nil,
            tagIds: []
        )
        var commands: [Command] = [addGeometryCmd, addFeatureCmd, addCollaborationCmd]
        commands.append(contentsOf: _addPhoto(
            imageData,
            tags: tags,
            description: description,
            toCollaboration: addCollaborationCmd.collaborationId
        ))
        return commands
    }

    /// Returns commands for adding new photo with given tags (some of them may require creation) to collaboration with given id
    /// Stores the upload data in the disk cache, creates and upload object and adds it to a collaboration
    func _addPhoto(_: Data,
                   tags: [TagViewModel],
                   description: String,
                   toCollaboration collaborationId: String) -> [Command]
    {
        // TODO: 90 do something with Data
//        let localUploadURL = try await _asyncStoreImage(data, key: uploadId)

        var commands: [Command] = []

        // add all new tags
        commands.append(contentsOf: tags
            .filter(\.newTag)
            .map { AddTagCommand(tagId: $0.id, name: $0.name) })

        let uploadId = generateRealmId()
        let addUploadCmd = AddUploadCommand(
            uploadId: uploadId,
            correlationId: uploadId,
            parentType: "Collaboration",
            parentId: collaborationId,
            authorId: userId,
            timestamp: Date.now.timeIntervalSince1970,
            name: nil,
            uploadDescription: description,
            url: nil,
            tagIds: tags.map(\.id)
        )
        commands.append(addUploadCmd)

        return commands
    }
}

// MARK: - run commands

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

    // TODO: 90 not needed?
//    func runActionCommand(_ command: ActionCommand) async throws {
//        if let remoteUpdater = remoteUpdater {
//            try await remoteUpdater.runActionCommand(command, writer: self)
//        } else {
//            try await write { realm in
//                try command.applyLocally(inRealm: realm)
//            }
//        }
//    }
}

// MARK: - utils

extension ProjectModel: ProjectModelWriter {
    /// Runs given closure on the writeQueue in the writeRealm transaction as an async function
    func write(_ closure: @escaping (Realm) throws -> Void) async throws {
        try await withUnsafeThrowingContinuation { continuation in
            self.writeQueue.async { [self] in
                do {
                    if writeRealm == nil {
                        writeRealm = try Realm(configuration: realmConfig, queue: writeQueue)
                    }
                    // at this point writeRealm is set or it threw an error
                    try writeRealm!.write {
                        try closure(writeRealm!)
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        } as Void
    }

    /// Stores the data in the local photos cache and returns the file URL
    func _asyncStoreImage(_ data: Data, key: String) async throws -> URL {
        try await withUnsafeThrowingContinuation { continuation in
            localPhotosCache.storeToDisk(data, forKey: key) { result in
                if case let .failure(error) = result.diskCacheResult {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning:
                        URL(fileURLWithPath: self.localPhotosCache.cachePath(forKey: key)))
                }
            }
        } as URL
    }
}
