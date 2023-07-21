import Foundation
import OSLog
import PhotosUI
import UIKit

/// Information about the photo to add
struct PhotoToAdd {
    /// UUID
    var uploadId: String
    /// Identifier of the asset selected from the camera roll (only present if the photo was selected using photo picker)
    var assetIdentifier: String?
    /// Suggested file name when asset selected frmo the camera roll
    var fileName: String?
    /// when the photo was taken
    var timestamp: Date
    /// key for LocalFiles
    var mediaKey: MediaKey
    /// small 100x100 image (with proper aspect ratio)
    var thumbnail: UIImage
    /// to layout before fetching from cache
    var height2Width: Double
    /// size of the file
    var fileSize: Int64
    /// photo annotations
    var annotations: Annotations?
}

/// View model for list of `PhotoToAdd`s
class PhotosToAddViewModel: NSObject {
    /// Errors for camera roll photos processing
    enum CameraRollError: Error, Equatable {
        case unsupportedType
        case thumbnailGenerationFailed
    }

    private let projectId: String
    unowned let localFiles: LocalFiles

    /// photos
    private(set) var photos: [PhotoToAdd]

    /// Allows for multiple delegates
    private var delegates = NSHashTable<PhotosToAddViewModelDelegate>.weakObjects()

    init(projectId: String, localFiles: LocalFiles) {
        self.projectId = projectId
        self.localFiles = localFiles
        photos = []
        super.init()
    }

    /// Add the photo at the end of photos array and notify the delegates on the main queue
    func add(_ photo: PhotoToAdd) {
        photos.append(photo)
        // notify delegates
        DispatchQueue.main.async {
            self.delegates.allObjects.forEach { $0.photoAdded?(atIndex: self.photos.count - 1) }
        }
    }

    /// Removes the photo at given index (also from cache) if the index is valid and notifies the delegates on the main queue.
    /// If the index is invalid it does nothing
    func remove(photoAtIndex index: Int) {
        guard index >= 0, index < photos.count else { return }
        photos.remove(at: index)
        DispatchQueue.main.async {
            self.delegates.allObjects.forEach { $0.photoRemoved?(atIndex: index) }
        }
    }

    /// Updates annotations for all photos (only if changed)
    func setAnnotations(_ annotations: [Annotations?]) {
        photos.indices.forEach { photos[$0].annotations = annotations[$0] }
    }

    /// Cleanup the current photosToAdd
    /// If the photos were used for uploads they should remain in cache, otherwise should be removed
    func clear(removeFromCache: Bool) {
        // remove the photos from local cache if we don't need them, don't wait for completion
        if removeFromCache {
            photos.forEach {
                localFiles.removeFile(forKey: $0.mediaKey, completionHandler: nil)
            }
        }
        photos = []
    }

    /// Get image data for given photo picker result and return PhotoToAdd
    /// Implementation based on: https://itnext.io/the-right-way-to-use-phpicker-and-retrieve-exif-data-without-requesting-library-permissions-in-336c13f87e3f
    private func getPhotoToAdd(forPickerResult result: PHPickerResult) async throws -> PhotoToAdd {
        let itemProvider: NSItemProvider = result.itemProvider
        guard itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) else {
            throw CameraRollError.unsupportedType
        }
        let data = try await itemProvider._asyncLoadDataRepresentation(forTypeIdentifier: UTType.image.identifier)
        guard let resizedData = resizeImage(imageData: data, maxResolution: 100),
              let thumbnail = UIImage(data: resizedData)
        else {
            throw CameraRollError.thumbnailGenerationFailed
        }
        let uploadId = generateRealmId()
        let mediaKey = MediaKey(
            localFileKeyWithProjectId: projectId,
            uploadId: uploadId,
            fileType: .jpeg,
            annotated: false
        )

        try await localFiles.store(data, forKey: mediaKey)

        return PhotoToAdd(
            uploadId: uploadId,
            assetIdentifier: result.assetIdentifier,
            fileName: itemProvider.suggestedName,
            timestamp: Date.now,
            mediaKey: mediaKey,
            thumbnail: thumbnail,
            height2Width: thumbnail.size.height / thumbnail.size.width,
            fileSize: Int64(data.count)
        )
    }

    /// Updates `photos` with given photo picker results.
    /// Converts picker results to PhotoToAdd using getPhotoToAdd(forPickerResult:)
    /// Uses `PhotoToAdd.assetIdentifier` to match current photos to picker results and add new ones + remove the ones
    /// that were unselected in this session.
    /// In case of errors returns the first of them but still updates the photos (if 1 of n photos fails to convert then the rest is still added)
    func update(withPickerResults results: [PHPickerResult]) async -> Error? {
        // clear the photos for single-session, we're replacing not adding
        if !UserDefaults.multiPhotoSessionEnabled {
            clear(removeFromCache: true)
        }

        /// for fast lookup if new picked photo is already in the photosToAdd
        let assetIdsInPhotosToAdd: Set<String> = Set(photos.compactMap(\.assetIdentifier))
        /// for fast lookup in picker results by assetIdentifier
        let assetIdsInPickerResults: Set<String> = Set(results.compactMap(\.assetIdentifier))

        // keep only non camera roll photos and the ones from the camera roll that are still selected
        // find indices to remove
        var indicesToRemove = [Int]()
        photos.enumerated().forEach { index, photo in
            if let assetIdentifier = photo.assetIdentifier, !assetIdsInPickerResults.contains(assetIdentifier) {
                indicesToRemove.append(index)
            }
        }
        for index in indicesToRemove.reversed() {
            remove(photoAtIndex: index)
        }

        var resultError: Error?
        for result in results {
            if let assetId = result.assetIdentifier, assetIdsInPhotosToAdd.contains(assetId) {
                // already added, skip
                continue
            }
            do {
                add(try await getPhotoToAdd(forPickerResult: result))
            } catch {
                Logger.camera.error("getPhotoToAdd error: \(error.localizedDescription, privacy: .public)")
                if resultError == nil {
                    resultError = error
                }
            }
        }
        return resultError
    }

    /// Add delegate
    /// No option for removal as delegates are stored weakly
    func addDelegate(_ delegate: PhotosToAddViewModelDelegate) {
        delegates.add(delegate)
    }
}

/// Delegate for `PhotosToAddViewModel`
///
/// see `SearchViewDelegate` for why it's @objc protocol
@objc protocol PhotosToAddViewModelDelegate: AnyObject {
    /// notifies that a photo was added at given index
    @objc optional func photoAdded(atIndex index: Int)
    /// notifies that a photo was removed at given index
    @objc optional func photoRemoved(atIndex index: Int)
}
