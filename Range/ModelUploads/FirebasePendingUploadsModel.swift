import Combine
import FirebaseCore
import FirebaseStorage
import Foundation
import Kingfisher
import Network
import OSLog
import Realm
import RealmSwift
import UIKit

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

    /// The Range id of the current logged in user
    let userId: String
    unowned let localFiles: LocalFiles
    unowned let mediaCache: MediaCache
    /// required for starting the ProjectModel after uploading a file for given project
    unowned let pendingActionsModel: PendingActionsModel

    /// uploading depends on the cellular/wifi user settings
    private let userSettings: UserSettings
    /// for storing the userSettings observer
    private var userSettingsUploadUsingCellularSubscriber: AnyCancellable?

    /// Configuration for creating realms to access this project objects
    let realmConfig: Realm.Configuration
    /// Main thread Realm
    let mainRealm: Realm

    /// Background serial queue to perform write operations to Realm
    let writeQueue = DispatchQueue(label: "pending-uploads-write-queue")
    /// Realm operating on `writeQueue`, initialized on first use
    var writeRealm: Realm!

    /// for monitoring network access
    let networkMonitor = NWPathMonitor()

    /// whether this is the first upload after start
    var firstUpload = true

    /// Initializes the pending uploads model
    /// - Parameters:
    ///     - inMemory:      optional parameter to create the Realm in memory (for tests), but default `false`
    /// - Warning: to be called on the Main thread
    init(
        userId: String,
        localFiles: LocalFiles,
        mediaCache: MediaCache,
        userSettings: UserSettings,
        pendingActionsModel: PendingActionsModel,
        inMemory: Bool = false
    ) throws {
        self.userId = userId
        self.pendingActionsModel = pendingActionsModel
        var config = Realm.Configuration.defaultConfiguration
        if inMemory {
            config.inMemoryIdentifier = "pendingUploads"
        } else {
            config.schemaVersion = 3
            config.fileURL!.deleteLastPathComponent()
            config.fileURL!.appendPathComponent("pendingUploads")
            config.fileURL!.appendPathExtension("realm")
            config.migrationBlock = { migration, oldSchemaVersion in
                FirebasePendingUploadsModel.migrate(migration, oldSchemaVersion)
            }
            Logger.model.info("pending uploads realm file url: \(config.fileURL?.path ?? "")")
        }
        config.objectTypes = [PendingUpload.self]
        realmConfig = config
        mainRealm = try Realm(configuration: realmConfig)
        self.localFiles = localFiles
        self.mediaCache = mediaCache
        self.userSettings = userSettings
    }

    /// Defines the migration of old Realm schemas
    class func migrate(_ migration: Migration, _ oldSchemaVersion: UInt64) {
        // schema version 2 replaces storagePath with projectId, uploadId and fileType
        if oldSchemaVersion < 2 {
            migration.enumerateObjects(ofType: PendingUpload.className()) { oldObject, _ in
                // no migration, remove the old pending uploads as this would require migrating
                // the files to new location too
                if let oldObject = oldObject {
                    migration.delete(oldObject)
                }
            }
        }

        // version 3 adds 'PendingUpload.annotated'
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
        observeUserSettings()
    }

    func stop() {
        networkMonitor.cancel()
        userSettingsUploadUsingCellularSubscriber?.cancel()
        userSettingsUploadUsingCellularSubscriber = nil
    }

    /// Observe user settings to detect change in uploadUsingCellular setting and potentially start uploads
    private func observeUserSettings() {
        userSettingsUploadUsingCellularSubscriber = userSettings.$uploadUsingCellular
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.writeQueue.async {
                    self._maybePerformUpload()
                }
            }
    }

    /// Assumes the upload file is already in the LocalFiles
    /// For images it stores the thumb data in the disk cache with given key and creates a `PendingUpload` to upload this image
    /// to Firebase storage
    /// The write operation will be executed on a `writeRealm` so not on the main thread
    func addPendingUpload(forKey key: MediaKey) async throws {
        if key.fileType.isImage {
            let localFileURL = localFiles.fileURL(forKey: key)
            let imageData = try Data(contentsOf: localFileURL)
            if UserSettings().saveImagesToDevice {
                guard let image = UIImage(data: imageData) else { throw "Failed to save image to device" }
                try await image._writeToSavedPhotosAlbum()
            }
            // store the thumbnail0, so it doesn;t have to be fetched and is ready in offline mode
            if let thumbnail0Data = resizeImage(imageData: imageData, maxResolution: _thumbnail0Size) {
                try await localFiles.store(thumbnail0Data, forKey: key.forThumbnail(0))
            }
            if let thumbnail1Data = resizeImage(imageData: imageData, maxResolution: _thumbnail1Size) {
                try await localFiles.store(thumbnail1Data, forKey: key.forThumbnail(1))
            }
        }
        try await _asyncRealmWriteOnQueue(queue: writeQueue, realm: writeRealm) { realm in
            let pendingUpload = PendingUpload(key)
            let pendingUploads = realm.objects(PendingUpload.self)
            if pendingUploads.contains(where: { $0 == pendingUpload }) {
                Logger.storage.debug(
                    "Pending upload for uploadId \(pendingUpload.uploadId) is already in pending uploads, ignore."
                )
                return
            }
            realm.add(pendingUpload)
            self.writeQueue.async {
                self._maybePerformUpload()
            }
        }
    }

    /// Return true if connected and the connection is not "expensive" (in terms of NWPath, which means it's not cellular)
    func _networkConditionsMet() -> Bool {
        if userSettings.uploadUsingCellular {
            // any network is good
            return networkMonitor.currentPath.status == .satisfied
        } else {
            // "wifi" only
            return networkMonitor.currentPath.status == .satisfied && !networkMonitor.currentPath.isExpensive
        }
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
                    .debug("Network conditions not met, upload \(pendingUpload.uploadId) will not be performed")
                return
            }
            // initial upload after start, let's force it and not check for isUploading,
            // in case the app crashed with upload.isUploading == true
            if !firstUpload {
                guard pendingUpload.isUploading == false else {
                    Logger.storage
                        .debug("Pending upload \(pendingUpload.uploadId) is currently uploading")
                    return
                }
            }
            let currentTimeInterval = Date.now.timeIntervalSince1970
            guard pendingUpload.shouldPerform(at: currentTimeInterval) else {
                if let nextAttemptAt = pendingUpload.nextAttemptAt {
                    let nextTryIn = nextAttemptAt - currentTimeInterval
                    Logger.storage
                        .debug(
                            "Should not perform upload yet \(pendingUpload.uploadId), waiting for \(nextTryIn) seconds"
                        )
                    // schedule another upload based on the `nextAttemptAt`
                    writeQueue.asyncAfter(
                        deadline: .now() + nextTryIn
                    ) { [weak self] in
                        self?._maybePerformUpload()
                    }
                } else {
                    Logger.storage.debug("Should not perform upload yet \(pendingUpload.uploadId)")
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

        let mediaKey = try await _asyncOnQueue(queue: writeQueue) {
            upload.mediaKey
        }
        let uploadRef = mediaCache.storage.reference(withPath: mediaKey.storagePath)
        let cacheFileURL = localFiles.fileURL(forKey: mediaKey)
        let metadata = StorageMetadata()
        metadata.contentType = mediaKey.fileType.mimeType
        // never expires = 1 year as advised by the standard: https://stackoverflow.com/a/25201898
        metadata.cacheControl = "public, max-age=31536000"

        do {
            // upload the file
            Logger.storage.debug("Will upload file: \(mediaKey, privacy: .public)")

            // Start the project model to save the storageVersion for Upload
            // Don't initiate the firestore sync, we need a local save only
            let projectModel = try ProjectModel(
                userId: userId,
                projectId: mediaKey.projectId,
                localFiles: localFiles,
                mediaCache: mediaCache,
                pendingUploadsModel: self,
                pendingActionsModel: pendingActionsModel
            )
            try await projectModel.start()

            try await projectModel.write { realm in
                if realm.object(ofType: Upload.self, forPrimaryKey: mediaKey.uploadId) == nil {
                    throw "Upload object not yet in the local Database"
                }
            }

            let resultMetadata = try await uploadRef.putFileAsync(from: cacheFileURL, metadata: metadata)
            Logger.storage.debug("Uploaded file: \(mediaKey, privacy: .public)")

            let storageVersion = String(resultMetadata.generation)

            // pending upload can be removed
            try await _asyncRealmWriteOnQueue(queue: writeQueue, realm: writeRealm) { realm in
                realm.delete(upload)
            }

            try await _moveFileFromLocalFilesToMediaCache(forKey: mediaKey, storageVersion: storageVersion)

            // update the Upload in project model to store the storageVersion
            try await projectModel.write { realm in
                guard let upload = realm.object(ofType: Upload.self, forPrimaryKey: mediaKey.uploadId) else {
                    throw "Trying to upload a file but Upload doesn't exist"
                }
                upload.localStorageVersion.setMain(annotated: mediaKey.annotated, value: storageVersion)
            }
        } catch {
            Logger.storage.error("Error uploading file: \(error.localizedDescription)")
            // store the error for pending upload
            try await _asyncRealmWriteOnQueue(queue: writeQueue, realm: writeRealm) { _ in
                upload.isUploading = false
                upload.lastErrorMessage = error.localizedDescription
            }
        }
    }

    /// After the file is uploaded it has to be removed from the `localFiles` (as it is not expiring)
    /// It is moved to media cache so it's immediatelly available without downloading.
    private func _moveFileFromLocalFilesToMediaCache(
        forKey localKey: MediaKey,
        storageVersion: String
    ) async throws {
        // for main file and thumbnails
        let thumbnails: [Int?] = [nil, 0, 1]
        for thumbnail in thumbnails {
            /// a copy of the key but with a predefined storage version to be used for MediaCache
            let localThumbnailKey = localKey.forThumbnail(thumbnail)
            let storageKey = MediaKey(
                projectId: localKey.projectId,
                uploadId: localKey.uploadId,
                fileType: localKey.fileType,
                annotated: localKey.annotated,
                thumbnailNumber: thumbnail,
                storageVersion: storageVersion,
                storeInDiskCache: true
            )
            try await mediaCache.moveFileFromLocalFilesToMediaCache(from: localThumbnailKey, to: storageKey)
        }
    }
}
