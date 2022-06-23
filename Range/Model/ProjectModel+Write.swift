import CoreLocation
import Foundation
import Kingfisher
import RealmSwift
import Turf

/// convenience function for generating new realm id
private func generateId() -> String {
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
    /// - Returns: collaboration from the `mainRealm`
    @MainActor
    func createPhotoMarker(canvas: PDFCanvas,
                           coordinates: CLLocationCoordinate2D) async throws -> Collaboration
    {
        // read the canvas id on the main thread
        let canvasId = canvas.id
        // so we can later find and return it
        let collaborationId = generateId()

        try await _asyncWrite { realm in
            // resolve the canvas in the write realm
            guard let canvas = realm.object(ofType: PDFCanvas.self, forPrimaryKey: canvasId) else {
                // this shouldn't really happen as the canvas cannot be removed...
                throw ModelError.canvasNotFound
            }
            let geometry = Geometry(
                id: generateId(),
                annotationType: .photoMarker,
                geometry: .point(Point(coordinates))
            )
            let feature = Feature(id: generateId(), name: "")
            let collaboration = Collaboration(id: collaborationId, name: "", description: "")

            realm.add(geometry, update: .error)
            realm.add(feature, update: .error)
            realm.add(collaboration, update: .error)
            canvas.geometries.insert(geometry)
            geometry.features.insert(feature)
            feature.collaborations.insert(collaboration)
        }
        mainRealm.refresh()
        // force unwrap, it really should be there if it didn't throw
        return mainRealm.object(ofType: Collaboration.self, forPrimaryKey: collaborationId)!
    }

    /// Returns the first collaboration from the first feature from the geometry with given id.
    /// If geometry has no features it creates a feature.
    /// If feature has no collaborations it creates a collaboration
    /// Throws error if geometry with given id not found.
    /// Throws error if creation of feature or collaboration fails
    @MainActor
    func getOrAddCollaboration(forGeometryId geometryId: String) async throws -> Collaboration {
        try await _asyncWrite { realm in
            guard let geometry = realm.object(ofType: Geometry.self, forPrimaryKey: geometryId) else {
                throw ModelError.geometryNotFound
            }
            if geometry.features.isEmpty {
                let feature = Feature(id: generateId(), name: "")
                realm.add(feature, update: .error)
                geometry.features.insert(feature)
            }
            // now there should be a feature in geometry
            let feature = geometry.features[0]
            if feature.collaborations.isEmpty {
                let collaboration = Collaboration(id: generateId(), name: "", description: "")
                realm.add(collaboration, update: .error)
                feature.collaborations.insert(collaboration)
            }
        }
        mainRealm.refresh()
        return mainRealm.object(ofType: Geometry.self, forPrimaryKey: geometryId)!
            .features[0].collaborations[0]
    }

    /// Stores the upload data in the disk cache, creates and upload object and adds it to a collaboration
    @MainActor
    func addUpload(_ data: Data,
                   tags tagViewModels: [TagViewModel],
                   description: String,
                   toCollaboration collaboration: Collaboration) async throws -> Upload
    {
        let collaborationId = collaboration.id
        let uploadId = generateId()
        let localUploadURL = try await _asyncStoreImage(data, key: uploadId)
        let upload = Upload(
            id: uploadId,
            timestamp: Date.now.timeIntervalSince1970,
            url: localUploadURL,
            name: "",
            description: description
        )
        let tags = tagViewModels.map {
            Tag(id: $0.id, name: $0.name, lastApplied: Date.now.timeIntervalSince1970)
        }

        try await _asyncWrite { realm in
            guard let user = realm.object(ofType: Participant.self,
                                          forPrimaryKey: self.userId)
            else {
                throw ModelError.currentUserNotFound
            }
            guard let collaboration = realm.object(ofType: Collaboration.self,
                                                   forPrimaryKey: collaborationId)
            else {
                throw ModelError.collaborationNotFound
            }
            realm.add(upload)
            realm.add(tags, update: .modified)
            upload.tags.append(objectsIn: tags)
            tags.forEach { $0.uploads.insert(upload) }
            upload.author = user
            collaboration.uploads.insert(upload)
        }
        mainRealm.refresh()
        return mainRealm.object(ofType: Upload.self, forPrimaryKey: uploadId)!
    }
}

// MARK: - utils

extension ProjectModel {
    /// Runs given closure on the writeQueue in the writeRealm transaction as an async function
    func _asyncWrite(_ closure: @escaping (Realm) throws -> Void) async throws {
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
