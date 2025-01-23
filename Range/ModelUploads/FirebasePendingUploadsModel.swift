import Combine
import FirebaseCore
import FirebaseStorage
import Foundation
import Kingfisher
import Network
import OSLog
import RealmSwift
import Sentry
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
    let localFiles: LocalFiles
    let mediaCache: MediaCache
    /// required for starting the ProjectModel after uploading a file for given project
    let pendingActionsModel: PendingActionsModel

    /// uploading depends on the cellular/wifi user settings
    private let userSettings: UserSettings
    /// for storing the userSettings observer
    private var userSettingsUploadUsingCellularSubscriber: AnyCancellable?
    let userPreferences: UserPreferences

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

    enum PendingUploadsError: Error {
        case localFileNotFound
    }

    var stopped = false

    /// Initializes the pending uploads model
    /// - Parameters:
    ///     - inMemory:      optional parameter to create the Realm in memory (for tests), but default `false`
    /// - Warning: to be called on the Main thread
    init(
        userId: String,
        localFiles: LocalFiles,
        mediaCache: MediaCache,
        userSettings: UserSettings,
        userPreferences: UserPreferences,
        pendingActionsModel: PendingActionsModel,
        inMemory: Bool = false
    ) throws {
        self.userId = userId
        self.pendingActionsModel = pendingActionsModel
        var config = Realm.Configuration.defaultConfiguration
        if inMemory {
            config.inMemoryIdentifier = "pendingUploads"
        } else {
            config.schemaVersion = 4
            config.fileURL!.deleteLastPathComponent()
            config.fileURL!.appendPathComponent("user_\(userId)_pendingUploads")
            config.fileURL!.appendPathExtension("realm")
            config.migrationBlock = { migration, oldSchemaVersion in
                FirebasePendingUploadsModel.migrate(migration, oldSchemaVersion)
            }
            Logger.model.info("pending uploads realm file url: \(config.fileURL?.path ?? "")")
        }
        config.objectTypes = [PendingUpload.self]
        // TODO: after 1.8.0 this can be removed in the release after 1.8.0 (in which it's being introduced)
        do {
            try FirebasePendingUploadsModel.possiblyMigrateGlobalPendingUploads(userRealmConfig: config)
        } catch {
            Logger.model.error(
                "Failed to migrate global pending uploads to user local files \(error.localizedDescription)"
            )
        }
        realmConfig = config
        mainRealm = try Realm(configuration: realmConfig)
        self.localFiles = localFiles
        self.mediaCache = mediaCache
        self.userSettings = userSettings
        self.userPreferences = userPreferences
    }

    /// Moves files for obsolete "pendingUploads" directory/files to a db per user
    private static func possiblyMigrateGlobalPendingUploads(userRealmConfig: Realm.Configuration) throws {
        guard let newFileURL = userRealmConfig.fileURL else { return }
        var oldConfig = Realm.Configuration.defaultConfiguration
        oldConfig.fileURL!.deleteLastPathComponent()
        oldConfig.fileURL!.appendPathComponent("pendingUploads")
        oldConfig.fileURL!.appendPathExtension("realm")
        guard let oldFileURL = oldConfig.fileURL else { return }
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: oldFileURL.path) else { return }
        Logger.model.info("Migrating pending uploads from: \(oldFileURL.path) to: \(newFileURL.path)")
        try fileManager.copyItem(at: oldFileURL, to: newFileURL)
        _ = try Realm.deleteFiles(for: oldConfig)
        Logger.model.info("Migrated pending uploads from: \(oldFileURL.path) to: \(newFileURL.path)")
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
        // v4 adds PendingUpload.storageVersion?
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
        stopped = true
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
    /// Creates a `PendingUpload` to upload this image to Firebase storage
    /// The write operation will be executed on a `writeRealm` so not on the main thread
    override func addPendingUpload(forKey key: MediaKey) async throws {
        try await _asyncRealmWriteOnQueue(queue: writeQueue, realm: writeRealm) { realm in
            let pendingUpload = PendingUpload(key)
            let pendingUploads = realm.objects(PendingUpload.self)

            // Potentially drop any previous pending uploads for the same file.
            // So if we have mulitple pending uploads for an Upload annotations only the most recent
            // will be processed.
            // Annotated and not annotated versions don't collide, they are different from the pendingUpload
            // equality point of view.
            for upload in pendingUploads {
                if upload == pendingUpload {
                    Logger.storage.debug(
                        "Dropping pending upload for uploadId \(upload.uploadId) as a new version is added to pending uploads."
                    )
                    let mediaKeyToDropFromLocalFiles = upload.mediaKey
                    Task { [weak self] in
                        await self?.localFiles.removeFileAndThumbnails(forKey: mediaKeyToDropFromLocalFiles)
                    }
                    realm.delete(upload)
                }
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
            networkConditionsMet = networkMonitor.currentPath.status == .satisfied
        } else {
            // "wifi" only
            networkConditionsMet = networkMonitor.currentPath.status == .satisfied && !networkMonitor.currentPath.isExpensive
        }
        return networkConditionsMet
    }

    /// Checks if there's a PendingUpload waiting to be uploaded and runs the `_performUpload` async method (not waiting for it)
    /// if the network conditions are met and if the PendingUpload is not currently uploading (there should be only 1 file uploading at a time)
    ///
    /// To be invoked on the writeQueue
    func _maybePerformUpload() {
        guard !stopped else { return }
        if let pendingUpload = writeRealm.objects(PendingUpload.self)
            .sorted(byKeyPath: "_id", ascending: true)
            .first
        {
            hasPendingUploads = true
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
                    Logger.model
                        .error("Error performing upload: \(error.localizedDescription), stopped: \(self.stopped)")
                }
                // maybe there's another one to upload
                self.writeQueue.async {
                    self._maybePerformUpload()
                }
            }
            firstUpload = false
        } else {
            hasPendingUploads = false
        }
    }

    /// Perform given PendingUpload and remove if succeeded or update with error if failed
    /// - Returns: `true` if it was performed
    /// To be invoked from the writeQueue
    func _performUpload(_ pendingUpload: PendingUpload) async throws {
        // increase the retry count
        try await _asyncRealmWriteOnQueue(queue: writeQueue, realm: writeRealm) { _ in
            pendingUpload.retryCount += 1
            pendingUpload.nextAttemptAt = Date.now.timeIntervalSince1970
                + min(pow(2, Double(pendingUpload.retryCount)), self.maxBackoff)
        }

        let mediaKey = try await _asyncOnQueue(queue: writeQueue) {
            pendingUpload.mediaKey
        }
        let uploadRef = mediaCache.storage.reference(withPath: mediaKey.storagePath)

        guard localFiles.hasFile(forKey: mediaKey) else {
            Logger.storage.error("File not found for pending upload \(mediaKey, privacy: .public), aborting!")
            // remove the pending upload
            try await _asyncRealmWriteOnQueue(queue: writeQueue, realm: writeRealm) { realm in
                realm.delete(pendingUpload)
            }
            SentrySDK.capture(error: PendingUploadsError.localFileNotFound) { scope in
                scope.setExtras([
                    "projectId": mediaKey.projectId,
                    "uploadId": mediaKey.uploadId,
                    "annotated": mediaKey.annotated,
                ])
            }
            return
        }

        let cacheFileURL = localFiles.fileURL(forKey: mediaKey)

        let metadata = StorageMetadata()
        metadata.contentType = mediaKey.fileType.mimeType
        // never expires = 1 year as advised by the standard: https://stackoverflow.com/a/25201898
        metadata.cacheControl = "public, max-age=31536000"

        do {
            // upload the file
            Logger.storage.info("Will upload file: \(mediaKey, privacy: .public), stopped: \(self.stopped)")

            // Start the project model to save the storageVersion for Upload
            // Don't initiate the firestore sync, we need a local save only
            let projectModel = try ProjectModel(
                userId: userId,
                projectId: mediaKey.projectId,
                localFiles: localFiles,
                mediaCache: mediaCache,
                userPreferences: userPreferences,
                pendingUploadsModel: self,
                pendingActionsModel: pendingActionsModel
            )
            try await projectModel.start()

            var uploadExists = false
            try await projectModel.write { realm in
                uploadExists = realm.object(ofType: Upload.self, forPrimaryKey: mediaKey.uploadId) != nil
            }
            Logger.storage.debug("Upload \(mediaKey, privacy: .public) existst in local db: \(uploadExists), stopped: \(self.stopped)")

            if uploadExists {
                let resultMetadata = try await uploadRef.putFileAsync(from: cacheFileURL, metadata: metadata)
                Logger.storage.info("Uploaded file: \(mediaKey, privacy: .public), stopped: \(self.stopped)")

                let storageVersion = String(resultMetadata.generation)

                // pending upload can be removed
                try await _asyncRealmWriteOnQueue(queue: writeQueue, realm: writeRealm) { realm in
                    realm.delete(pendingUpload)
                }

                try await _moveFileFromLocalFilesToMediaCache(forKey: mediaKey, storageVersion: storageVersion)

                // update the Upload in project model to store the storageVersion
                try await projectModel.write { realm in
                    guard let upload = realm.object(ofType: Upload.self, forPrimaryKey: mediaKey.uploadId) else {
                        Logger.storage.warning(
                            "No Upload object in the database, not updating localStorageVersion for pending upload: \(mediaKey, privacy: .public)"
                        )
                        return
                    }
                    upload.localStorageVersion.setMain(annotated: mediaKey.annotated, value: storageVersion)
                }
                Logger.storage.info("Did upload file: \(mediaKey, privacy: .public), stopped: \(self.stopped)")
            } else {
                // Upload in Firestore is gone, remove the pending upload and local files
                Logger.storage.warning(
                    "No Upload object in the database, ignoring (and removing) pending upload: \(mediaKey, privacy: .public)"
                )
                try await _asyncRealmWriteOnQueue(queue: writeQueue, realm: writeRealm) { realm in
                    realm.delete(pendingUpload)
                }
                await localFiles.removeFileAndThumbnails(forKey: mediaKey)
            }

        } catch {
            Logger.storage.error("Error uploading file: \(error.localizedDescription), stopped: \(self.stopped)")
            // store the error for pending upload
            try await _asyncRealmWriteOnQueue(queue: writeQueue, realm: writeRealm) { _ in
                guard !pendingUpload.isInvalidated else { return }
                pendingUpload.isUploading = false
                pendingUpload.lastErrorMessage = error.localizedDescription
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
                storeInDiskCache: true,
                isFromLocalFiles: false
            )
            try await mediaCache.moveFileFromLocalFilesToMediaCache(from: localThumbnailKey, to: storageKey)
        }
    }
}
