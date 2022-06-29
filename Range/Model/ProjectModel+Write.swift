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
    /// Creates a new geometry of photoMarker type and adds it to given canvas.
    /// Creates a feature attached to this geometry and creates the collaboration attached to the feature.
    /// Returns the collaboration
    ///
    /// Marked with @MainActor as it needs to run on the main thread to have access to main thread realm objects (canvas)
    /// The write operation will be executed on a `writeRealm` so not on the main thread
    ///
    /// - Parameters:
    ///     - canvas: should be from the `mainRealm`
    ///     - coordinates: the coordinates for the photo marker
    /// - Returns: CreatePhotoMarkerCommand that contains collaborationId, etc.
    @MainActor
    func createPhotoMarker(canvas: PDFCanvas,
                           coordinates: CLLocationCoordinate2D) async throws -> CreatePhotoMarkerCommand
    {
        // set ids to support retry, etc.
        let collaborationId = generateRealmId()
        let command = CreatePhotoMarkerCommand(
            canvasId: canvas.id,
            geometryId: generateRealmId(),
            featureId: generateRealmId(),
            collaborationId: collaborationId,
            coordinates: coordinates
        )
        try await runActionCommand(.createPhotoMarker(command))
        return command
    }

    /// Returns the first collaboration from the first feature from the geometry with given id.
    /// If geometry has no features it creates a feature.
    /// If feature has no collaborations it creates a collaboration
    /// Throws error if geometry with given id not found.
    /// Throws error if creation of feature or collaboration fails
    @MainActor
    func getOrAddCollaboration(forGeometryId geometryId: String) async throws -> String {
        // TODO: 44 from write perspective the operations are:
        // 1. maybe create a feature
        // 2. maybe create a collaboration
        try await write { realm in
            guard let geometry = realm.object(ofType: Geometry.self, forPrimaryKey: geometryId) else {
                throw ModelError.geometryNotFound
            }
            let createFeature: Bool = geometry.features.isEmpty
            let createCollaboration: Bool
            if createFeature {
                createCollaboration = true
            } else {
                createCollaboration = geometry.features[0].collaborations.isEmpty
            }

            if createFeature {}
            // now there should be a feature in geometry
//                let feature = Feature(id: generateRealmId(), name: "")
//                realm.add(feature, update: .error)
//                geometry.features.insert(feature)
//            let feature = geometry.features[0]
//            if feature.collaborations.isEmpty {
//                let collaboration = Collaboration(id: generateRealmId(), name: "", description: "")
//                realm.add(collaboration, update: .error)
//                feature.collaborations.insert(collaboration)
//            }
        }
        // TODO: 44 here
        return ""
    }

    /// Stores the upload data in the disk cache, creates and upload object and adds it to a collaboration
    @MainActor
    func addUpload(_ data: Data,
                   tags tagViewModels: [TagViewModel],
                   description: String,
                   collaborationId: String) async throws -> AddUploadCommand
    {
        let uploadId = generateRealmId()
        let localUploadURL = try await _asyncStoreImage(data, key: uploadId)
        let command = AddUploadCommand(uploadId: uploadId,
                                       collaborationId: collaborationId,
                                       userId: userId,
                                       localUploadURL: localUploadURL,
                                       tags: tagViewModels,
                                       description: description)
        try await runActionCommand(.addUpload(command))
        return command
    }
}

// MARK: - commands

extension ProjectModel {
    func runCommand(_ command: Command) async throws {
        // try to apply remotely
        if let remoteUpdater = remoteUpdater {
            if try await remoteUpdater.runCommand(command, writer: self) {
                return
            }
        }
        // if remote not supported then try locally
        if let command = command as? LocalCommand {
            try await command.applyLocally(writer: self)
        }
    }

    func runActionCommand(_ command: ActionCommand) async throws {
        if let remoteUpdater = remoteUpdater {
            try await remoteUpdater.runActionCommand(command, writer: self)
        } else {
            try await command.applyLocally(writer: self)
        }
    }
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
