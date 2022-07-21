import CoreLocation
import Foundation
import Kingfisher
import RealmSwift
import Turf

/// convenience function for generating new realm id
func generateRealmId() -> String {
    UUID().uuidString.lowercased()
}

/// ProjectModel extension for write operations
extension ProjectModel {
    // TODO: 44 tests for these methods... or maybe actually tests for _commands and the execution should be somewhere else?

    /// If geometry with given id has no feature it creates the feature
    /// If the feature has no collaboration it creates the collaboration
    /// Creates all new tags and creates an upload with given tags and description and adds it to a collaboration
    /// Throws error if geometry with given id not found.
    ///
    /// Marked with @MainActor as it needs to run on the main thread to have access to main thread realm objects (canvas)
    /// The write operation will be executed on a `writeRealm` so not on the main thread
    ///
    /// - Parameters:
    ///     - imageData: the data for the image
    ///     - tags: array of tags, existing or new ones
    ///     - description: upload description
    ///     - geometryId: 'photoMarker' to add the upload to (to it's first feature/first collaboration)
    @MainActor
    func addPhoto(
        _ imageData: Data,
        tags: [TagViewModel],
        description: String,
        toCollaborationForGeometryId geometryId: String
    ) async throws {
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

        commands.append(contentsOf:
            _commandsForAddPhoto(imageData, tags: tags, description: description,
                                 toCollaboration: collaborationId))
        try await runCommands(commands)
    }

    /// Creates a new geometry of photoMarker type and adds it to given canvas.
    /// Creates a feature attached to this geometry and creates the collaboration attached to the feature.
    /// Creates all new tags and creates an upload with given tags and description and adds it to a collaboration
    ///
    /// Marked with @MainActor as it needs to run on the main thread to have access to main thread realm objects (canvas)
    /// The write operation will be executed on a `writeRealm` so not on the main thread
    ///
    /// - Parameters:
    ///     - imageData: the data for the image
    ///     - tags: array of tags, existing or new ones
    ///     - description: upload description
    ///     - coordinates: the coordinates for the photo marker
    ///     - canvas: should be from the `mainRealm`
    /// - Returns: id of the newly created geometry
    @MainActor
    func addPhoto(
        _ imageData: Data,
        tags: [TagViewModel],
        description: String,
        at coordinates: CLLocationCoordinate2D,
        in canvas: PDFCanvas
    ) async throws -> String {
        let addGeometryCmd = AddGeometryCommand(
            geometryId: generateRealmId(),
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
        commands.append(contentsOf: _commandsForAddPhoto(
            imageData,
            tags: tags,
            description: description,
            toCollaboration: addCollaborationCmd.collaborationId
        ))

        try await runCommands(commands)
        return addGeometryCmd.geometryId
    }

    /// Returns commands for adding new photo with given tags (some of them may require creation) to collaboration with given id
    /// Stores the upload data in the disk cache, creates and upload object and adds it to a collaboration
    func _commandsForAddPhoto(_: Data,
                              tags: [TagViewModel],
                              description: String, toCollaboration collaborationId: String) -> [Command]
    {
        // TODO: 44 do something with Data

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

//    func addPhoto(_ data: Data,
//                  tags tagViewModels: [TagViewModel],
//                  description: String,
//                  collaborationId: String) async throws -> AddUploadCommand
//    {
//        let uploadId = generateRealmId()
//        let localUploadURL = try await _asyncStoreImage(data, key: uploadId)
//        let command = AddUploadCommand(uploadId: uploadId,
//                                       collaborationId: collaborationId,
//                                       userId: userId,
//                                       localUploadURL: localUploadURL,
//                                       tags: tagViewModels,
//                                       description: description)
//        try await runActionCommand(.addUpload(command))
//        return command
//    }
}

// MARK: - commands

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
