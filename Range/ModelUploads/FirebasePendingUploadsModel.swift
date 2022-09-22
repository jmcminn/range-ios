import FirebaseCore
import FirebaseStorage
import FirebaseStorageSwift
import Foundation
import Kingfisher
import Network
import OSLog
import Realm
import RealmSwift

/// Manages the PendingUploads and schedules them for upload to Firebase Storage using the `_maybePerformUpload` function.
/// It performs uploads sequentially, always trying the oldest `PendingUpload`
/// There are multiple triggers for trying the upload:
/// - when the model is started
/// - when a `PendingUpload` is added using `addPendingUpload`
/// - when the network condition is changed and  satisfies the `_networkConditionsMet`
/// - when upload is completed the model immediately tries again (in case there's a number of `PendingUploads` waiting)
/// - when upload should wait due to exponential backoff, the next upload is scheduled for the future
///
/// Also responsible for configuring the Realm for pending uploads
/// Unlike the `ProjectModel`, there's only one Realm for all pending uploads (no matter what project they belong too).
/// This is because user may have multiple pending uploads from different projects, so this way it's easier to manage all of them.
class FirebasePendingUploadsModel: PendingUploadsModel {
    /// maximum backoff for retrying actions (in seconds)
    private let maxBackoff: TimeInterval = 64

    unowned let imageCaches: ImageCaches

    /// Configuration for creating realms to access this project objects
    let realmConfig: Realm.Configuration
    /// Main thread Realm
    let mainRealm: Realm

    /// Background serial queue to perform write operations to Realm
    let writeQueue = DispatchQueue(label: "pending-uploads-write-queue")
    /// Realm operating on `writeQueue`, initialized on first use
    var writeRealm: Realm!

    /// Background serial queue to perform firebase storage upload operations
    let uploadQueue = DispatchQueue(label: "pending-uploads-upload-queue")

    /// for monitoring network access
    let networkMonitor = NWPathMonitor()

    /// whether this is the first upload after start
    var firstUpload = true

    /// Initializes the pending uploads model
    /// - Parameters:
    ///     - inMemory:      optional parameter to create the Realm in memory (for tests), but default `false`
    /// - Warning: to be called on the Main thread
    init(imageCaches: ImageCaches, inMemory: Bool = false) throws {
        var config = Realm.Configuration.defaultConfiguration
        // TODO: [db-migration] for now we just remove the Realm and resync if migration needed...
        config.deleteRealmIfMigrationNeeded = true
        if inMemory {
            config.inMemoryIdentifier = "pendingUploads"
        } else {
            config.fileURL!.deleteLastPathComponent()
            config.fileURL!.appendPathComponent("pendingUploads")
            config.fileURL!.appendPathExtension("realm")
            Logger.model.info("pending uploads realm file url: \(config.fileURL?.path ?? "")")
        }
        config.objectTypes = [PendingUpload.self]
        realmConfig = config
        mainRealm = try Realm(configuration: realmConfig)
        self.imageCaches = imageCaches
    }

    /// Starts synchronization - observes all relevant paths and updates the db.
    func start() async throws {
        try await _asyncOnQueue(queue: writeQueue) {
            self.writeRealm = try Realm(configuration: self.realmConfig, queue: self.writeQueue)
        }
        // check if there are any uploads pending to be uploaded
        writeQueue.async {
            self._maybePerformUpload()
        }
        networkMonitor.pathUpdateHandler = { [weak self] _ in
            guard let self = self else { return }
            // network conditions have changed, check if uploads can be performed and try, maybe
            // something is pending
            if self._networkConditionsMet() {
                self._maybePerformUpload()
            }
        }
        networkMonitor.start(queue: writeQueue)
    }

    func stop() {
        networkMonitor.cancel()
    }

    /// Assumes the image is already in the Images.localPhotosCache
    /// Stores the thumb data in the disk cache with given key and creates a `PendingUpload` to upload this image
    /// to Firebase storage
    /// The write operation will be executed on a `writeRealm` so not on the main thread
    func addPendingUpload(key: String) async throws {
        let cachePath = imageCaches.localPhotosCache.cachePath(forKey: key)
        let imageData = try Data(contentsOf: URL(fileURLWithPath: cachePath))
        // store the thumbnail0, so it doesn;t have to be fetched and is ready in offline mode
        if let thumbnail0Data = resizeImage(imageData: imageData, maxResolution: 200) {
            let thumbnail0Key = thumbnailKey(forUploadKey: key, thumbnailNumber: 0)
            try await imageCaches.localPhotosCache._asyncStoreToDisk(thumbnail0Data, forKey: thumbnail0Key)
        }
        if let thumbnail1Data = resizeImage(imageData: imageData, maxResolution: 500) {
            let thumbnail1Key = thumbnailKey(forUploadKey: key, thumbnailNumber: 1)
            try await imageCaches.localPhotosCache._asyncStoreToDisk(thumbnail1Data, forKey: thumbnail1Key)
        }
        try await _asyncRealmWriteOnQueue(queue: writeQueue, realm: writeRealm) { realm in
            let pendingUpload = PendingUpload(key)
            realm.add(pendingUpload)
            self.writeQueue.async {
                self._maybePerformUpload()
            }
        }
    }

    /// After the image is uploaded it has to be removed from the `localPhotosCache` (as it is not expiring)
    /// It is moved to downloads cache so it's immediatelly available without downloading.
    private func _moveImageFromLocalPhotosCache(forKey key: String) async throws {
        try await imageCaches.moveDataFromLocalPhotosToDownloadsCache(forKey: key)
        try await imageCaches.moveDataFromLocalPhotosToDownloadsCache(forKey:
            thumbnailKey(forUploadKey: key, thumbnailNumber: 0))
        try await imageCaches.moveDataFromLocalPhotosToDownloadsCache(forKey:
            thumbnailKey(forUploadKey: key, thumbnailNumber: 1))
    }

    /// Return true if connected and the connection is not "expensive" (in terms of NWPath, which means it's not cellular)
    func _networkConditionsMet() -> Bool {
        networkMonitor.currentPath.status == .satisfied && !networkMonitor.currentPath.isExpensive
    }

    /// Checks if there's a PendingUpload waiting to be uploaded and runs the `_performUpload` async method (not waiting for it)
    /// if the network conditions are met and if the PendingUpload is not currently uploading (there should be only 1 file uploading at a time)
    ///
    /// To be invoked on the writeQueue
    func _maybePerformUpload() {
        if let pendingUpload = writeRealm.objects(PendingUpload.self)
            .sorted(byKeyPath: "_id", ascending: true)
            .first
        {
            guard _networkConditionsMet() else {
                Logger.storage
                    .debug("Network conditions not met, upload \(pendingUpload.storagePath) will not be performed")
                return
            }
            // initial upload after start, let's force it and not check for isUploading,
            // in case the app crashed with upload.isUploading == true
            if !firstUpload {
                guard pendingUpload.isUploading == false else {
                    Logger.storage
                        .debug("Pending upload \(pendingUpload.storagePath) is currently uploading")
                    return
                }
            }
            let currentTimeInterval = Date.now.timeIntervalSince1970
            guard pendingUpload.shouldPerform(at: currentTimeInterval) else {
                if let nextAttemptAt = pendingUpload.nextAttemptAt {
                    let nextTryIn = nextAttemptAt - currentTimeInterval
                    Logger.storage
                        .debug(
                            "Should not perform upload yet \(pendingUpload.storagePath), waiting for \(nextTryIn) seconds"
                        )
                    // schedule another upload based on the `nextAttemptAt`
                    writeQueue.asyncAfter(
                        deadline: .now() + nextTryIn
                    ) { [weak self] in
                        self?._maybePerformUpload()
                    }
                } else {
                    Logger.storage.debug("Should not perform upload yet \(pendingUpload.storagePath)")
                }
                return
            }
            // mark the PendingUpload as uploading
            do {
                try writeRealm.write {
                    pendingUpload.isUploading = true
                }
            } catch {
                Logger.storage.debug("Couldn't update pending upload 'isUploading'")
                // couldn't write to realm, maybe next time...
                return
            }
            Task {
                do {
                    try await _performUpload(pendingUpload)
                } catch {
                    Logger.model.error("Error performing upload: \(error.localizedDescription)")
                }
                // maybe there's another one to upload
                self.writeQueue.async {
                    self._maybePerformUpload()
                }
            }
            firstUpload = false
        }
    }

    /// Perform given PendingUpload and remove if succeeded or update with error if failed
    /// - Returns: `true` if it was performed
    /// To be invoked from the writeQueue
    func _performUpload(_ upload: PendingUpload) async throws {
        // increase the retry count
        try await _asyncRealmWriteOnQueue(queue: writeQueue, realm: writeRealm) { _ in
            upload.retryCount += 1
            upload.nextAttemptAt = Date.now.timeIntervalSince1970
                + min(pow(2, Double(upload.retryCount)), self.maxBackoff)
        }

        let storagePath = try await _asyncOnQueue(queue: writeQueue) {
            upload.storagePath
        }
        let uploadRef = imageCaches.storage.reference(withPath: storagePath)
        let cacheFileURL = URL(fileURLWithPath: imageCaches.localPhotosCache.cachePath(forKey: storagePath))
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        // never expires = 1 year as advised by the standard: https://stackoverflow.com/a/25201898
        metadata.cacheControl = "public, max-age=31536000"

        do {
            // upload the file
            Logger.storage.debug("Will upload file: \(storagePath, privacy: .public)")
            _ = try await uploadRef.putFileAsync(from: cacheFileURL, metadata: metadata)
            Logger.storage.debug("Uploaded file: \(storagePath, privacy: .public)")

            // pending upload can be removed
            try await _asyncRealmWriteOnQueue(queue: writeQueue, realm: writeRealm) { realm in
                realm.delete(upload)
            }

            // move the image from local photos cache to the downloads cache
            try await _moveImageFromLocalPhotosCache(forKey: storagePath)
        } catch {
            Logger.storage.error("Error uploading file: \(error.localizedDescription)")
            // store the error for pending upload
            try await _asyncRealmWriteOnQueue(queue: writeQueue, realm: writeRealm) { _ in
                upload.isUploading = false
                upload.lastErrorMessage = error.localizedDescription
            }
        }
    }
}
