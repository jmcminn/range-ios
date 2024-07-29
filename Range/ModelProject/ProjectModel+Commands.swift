import CoreLocation
import Foundation
import Kingfisher
import OSLog
import RealmSwift
import Turf
import UIKit

// MARK: - run commands

extension ProjectModel {
    /// Run command locally and add action for running backend action.
    /// The backend action is queued by `PendingActionsModel` and not awaited here.
    func run(_ command: Command?) async throws {
        guard let command = command else { return }
        try await run([command])
    }

    /// Run commands locally in one realm transaction and add actions for running backend actions.
    /// The backend actions are queued by `PendingActionsModel` and not awaited here.
    func run(_ commands: [Command]) async throws {
        guard !commands.isEmpty else { return }

        // Execute the commands locally and store actions for server side execution.
        // They both can fail. So first prepare the commands for storage,  if it doesn't fail
        // then execute the local action and then store the action (this will not fail). So
        // local execution and storing for server side is "transactional".

        // 1. First prepare the action data (it might fail)
        let actionsData = try commands.map { command in
            try pendingActionsModel.prepareAction(Action(projectId: projectId, command: command))
        }

        // 2. Then apply the commands in Realm (it might fail)
        try await write { realm in
            for localCommand in commands.compactMap({ $0 as? LocalCommand }) {
                try localCommand.apply(inRealm: realm)
            }
        }

        // 3. Add pending uploads
        for pendingUploadCommand in commands.compactMap({ $0 as? PendingUploadCommand }) {
            try await pendingUploadCommand.addPendingUploads(pendingUploadsModel)
        }

        // 4. Store the action for server side execution (will not fail).
        for actionData in actionsData {
            pendingActionsModel.addAction(data: actionData)
        }
    }

    /// A convenience wrapper for the `run` function that does the async call and catches and logs the error.
    /// It accepts multiple commands and runs them sequentially.
    /// It also accepts an optional callback which is invoked with the optional Error
    func run(_ commands: [Command?], callback: ((Error?) -> Void)?) {
        Task {
            do {
                try await run(commands.compactMap { $0 })
                DispatchQueue.main.async {
                    callback?(nil)
                }
            } catch {
                Logger.model.error("command error: \(error.localizedDescription, privacy: .public)")
                DispatchQueue.main.async {
                    callback?(error)
                }
            }
        }
    }

    /// A convenience wrapper for the `run` function that does the async call and catches and logs the error.
    /// It also accepts an optional callback which is invoked with the optional Error
    func run(_ command: Command?, callback: ((Error?) -> Void)?) {
        run([command], callback: callback)
    }
}

// MARK: - commands

extension ProjectModel {
    /// Adds given photo to pending uploads and returns command for:
    /// - creating all new tags and an upload with given tags and description and adding it to a collaboration
    /// Throws error if geometry with given id not found, or it has no colllaboration
    ///
    /// Marked with @MainActor as it needs to run on the main thread to have access to main thread realm objects (canvas)
    /// The write operation will be executed on a `writeRealm` so not on the main thread
    ///
    /// - Parameters:
    ///     - photoToAdd: the data for the image to add
    ///     - tags: array of tags, existing or new ones
    ///     - description: upload description
    ///     - geometryId: 'photoMarker' to add the upload to (to it's first collaboration)
    ///     - correlationId: set if the upload is a new versions of some other upload
    func addPhoto(
        _ photoToAdd: PhotoToAdd,
        tags: [TagViewModel],
        description: String,
        toCollaborationForGeometryId geometryId: String,
        correlationId: String? = nil
    ) throws -> Command {
        guard let geometry = mainRealm.object(ofType: Geometry.self, forPrimaryKey: geometryId) else {
            throw ModelError.geometryNotFound
        }
        guard let collaboration = geometry.collaborations.first else {
            throw ModelError.collaborationNotFound
        }

        analytics?._trackProjectEvent(name: "media uploaded", self, [
            "mediaType": photoToAdd.mediaKey.fileType.rawValue,
        ])
        if photoToAdd.annotatedMediaKey != nil {
            analytics?._trackProjectEvent(name: "photo annotated", self, [:])
        }
        if photoToAdd.isCanvasSnippet {
            analytics?._trackProjectEvent(name: "snippet created", self, [:])
        }
        tags.forEach { _ in
            analytics?._trackProjectEvent(name: "tag added", self, [:])
        }

        return CreateUploadCommand(
            authorId: userId,
            collaborationId: collaboration.id,
            tags: tags.map(CommandTag.init(fromViewModel:)),
            uploadDescription: description,
            upload: CommandUpload(fromPhotoToAdd: photoToAdd),
            correlationId: correlationId
        )
    }

    @MainActor
    func addMedia(_ data: Data, name: String, fileType: Upload.FileType,
                  toCollaboration collaboration: Collaboration) async throws -> Command
    {
        let uploadId = generateRealmId()
        let mediaKey = MediaKey.localFilesKeyWithAutoStorageVersion(projectId: projectId, uploadId: uploadId,
                                                                    fileType: fileType, annotated: false)

        try await localFiles.store(data, forKey: mediaKey)
        try await localFiles.generateAndStoreThumbnails(data, forKey: mediaKey)
        analytics?._trackProjectEvent(name: "media uploaded", self, [
            "mediaType": fileType.rawValue,
        ])

        return CreateUploadCommand(
            authorId: userId,
            collaborationId: collaboration.id,
            tags: [],
            upload: CommandUpload(mediaKey: mediaKey, fileSize: Int64(data.count), name: name)
        )
    }

    /// Adds given photos to pending uploads and returns command for:
    /// - creating a new geometry of photoMarker type and adding it to given canvas.
    /// - creating a collaboration attached to the geometry.
    /// - creating all new tags and an upload with given tags and description and adding it to a collaboration
    ///
    /// Marked with @MainActor as it needs to run on the main thread to have access to main thread realm objects (canvas)
    /// The write operation will be executed on a `writeRealm` so not on the main thread
    ///
    /// - Parameters:
    ///     - coordinates: the coordinates for the photo marker
    ///     - canvas: should be from the `mainRealm`
    ///     - geometryId: this id will be used for the newly created geometry
    ///     - isTask: whether it is a task or photo collaboration. If task it'll assign the initial status
    ///     - name: collaboration name
    ///     - collaborationDescription: collaboration description
    ///     - assignee: assignee for the task
    ///     - dueDate:  due date for the task
    ///     - tags: tags for the task
    ///     - photosToAdd: the data for the images to add
    ///     - uploadTags: array of tags, existing or new ones, will be attached to each uploaded photo
    ///     - uploadDescription: upload description, will be attached to each uploaded photo
    @MainActor
    func createCollaboration(
        at coordinates: CLLocationCoordinate2D,
        in canvas: Canvas,
        withGeometryId geometryId: String,
        isTask: Bool,
        name: String? = nil,
        collaborationDescription: String? = nil,
        assignee: Participant? = nil,
        dueDate: Date? = nil,
        tags: [TagViewModel] = [],
        followerIds: [String] = [],
        photosToAdd: [PhotoToAdd] = [],
        uploadTags: [TagViewModel] = [],
        uploadDescription: String? = nil
    ) async throws -> Command {
        if let canvasSource = canvas.currentCanvasSource {
            // The canvas source is set if it's used in UI and can theoretically be null here
            // (although it shouldn't happen if user is adding a pin)
            analytics?._trackProjectEvent(name: "collaboration created", self, [
                "collaborationType": isTask ? "task" : "photo",
                "canvasType": canvasSource.type.rawValue,
            ])
        }

        for photoToAdd in photosToAdd {
            analytics?._trackProjectEvent(name: "media uploaded", self, [
                "mediaType": photoToAdd.mediaKey.fileType.rawValue,
            ])
            // report tag added for each photo
            uploadTags.forEach { _ in
                analytics?._trackProjectEvent(name: "tag added", self, [:])
            }
            if photoToAdd.annotatedMediaKey != nil {
                analytics?._trackProjectEvent(name: "photo annotated", self, [:])
            }
            if photoToAdd.isCanvasSnippet {
                analytics?._trackProjectEvent(name: "snippet created", self, [:])
            }
        }
        tags.forEach { _ in
            analytics?._trackProjectEvent(name: "tag added", self, [:])
        }

        var status: Status?
        if isTask {
            guard let initialStatus = mainRealm.objects(Status.self).first(where: { $0.isInitial }) else {
                throw ModelError.statusNotFound
            }
            status = initialStatus
        }

        return CreateCollaborationCommand(
            authorId: userId,
            canvasId: canvas.id,
            geometryId: geometryId,
            coordinates: coordinates,
            statusId: status?.id,
            name: name,
            collaborationDescription: collaborationDescription,
            assigneeId: assignee?.id,
            dueDateTimestamp: dueDate,
            tags: tags.map(CommandTag.init(fromViewModel:)),
            followerIds: followerIds,
            uploadTags: uploadTags.map(CommandTag.init(fromViewModel:)),
            uploadDescription: uploadDescription,
            uploads: photosToAdd.map(CommandUpload.init(fromPhotoToAdd:))
        )
    }

    func convertPhotoCollaborationToTask(_ collaboration: Collaboration) throws -> Command? {
        let statuses = mainRealm.objects(Status.self)
        if let initialStatus = statuses.first(where: { $0.isInitial }) {
            return update(status: initialStatus, forCollaboration: collaboration)
        } else if let firstStatus = statuses.first {
            return update(status: firstStatus, forCollaboration: collaboration)
        } else {
            throw ModelError.statusNotFound
        }
    }

    /// Update upload with given tags.
    /// If adding (add is `true`) then append the tags to current upload tags for each upload.
    /// If add is `false` then replace the current tags with the newly provided ones
    func update(tags: [TagViewModel], forUpload uploadId: String, add: Bool = false) -> Command? {
        guard let upload = mainRealm.object(ofType: Upload.self, forPrimaryKey: uploadId) else { return nil }
        let existingTagIdsSet: Set<String> = Set(upload.tags.map(\.id))
        // only report tag added for newly attached tags
        let newTags = tags.filter { !existingTagIdsSet.contains($0.id) }
        newTags.forEach { _ in analytics?._trackProjectEvent(name: "tag added", self, [:]) }
        let updatedTags: [TagViewModel]
        if add {
            let currentTags = upload.tags.map { TagViewModel(fromTag: $0) }
            updatedTags = currentTags + newTags
        } else {
            updatedTags = tags
        }
        return UpdateUploadTagsCommand(uploadId: uploadId, tags: updatedTags.map(CommandTag.init(fromViewModel:)))
    }

    /// Create command for updating given Collaboration tags (only if tags are different than existing ones).
    /// The command creates new tags.
    func update(tags: [TagViewModel], forCollaboration collaboration: Collaboration) -> Command? {
        let tagIdsSet = Set(tags.map(\.id))
        let existingTagIdsSet: Set<String> = Set(collaboration.tags.map(\.id))
        guard tagIdsSet != existingTagIdsSet else { return nil }

        // only report tag added for newly attached tags
        tags.filter { !existingTagIdsSet.contains($0.id) }
            .forEach { _ in
                analytics?._trackProjectEvent(name: "tag added", self, [:])
            }

        return UpdateCollaborationTagsCommand(
            collaborationId: collaboration.id,
            tags: tags.map(CommandTag.init(fromViewModel:))
        )
    }

    /// Update collaboration with given tags.
    /// If adding (add is `true`) then append the tags to collaboration tags
    /// If add is `false` then replace the current tags with the newly provided ones
    func update(tags: [TagViewModel], forCollaboration collaborationId: String, add: Bool) -> Command? {
        guard let collaboration = mainRealm.object(ofType: Collaboration.self, forPrimaryKey: collaborationId)
        else { return nil }
        let existingTagIdsSet: Set<String> = Set(collaboration.tags.map(\.id))
        // only report tag added for newly attached tags
        tags.filter { !existingTagIdsSet.contains($0.id) }
            .forEach { _ in
                analytics?._trackProjectEvent(name: "tag added", self, [:])
            }
        return UpdateCollaborationTagsCommand(
            collaborationId: collaborationId,
            tags: tags.map(CommandTag.init(fromViewModel:)),
            add: add
        )
    }

    /// Create command for creating a new comment (or note if isNote = `true`) for given collaboration id.
    func addComment(commentText: String, isNote: Bool, toCollaboration collaborationId: String) -> Command {
        CreateCommentCommand.collaborationComment(
            collaborationId: collaborationId,
            authorId: userId,
            text: commentText,
            isNote: isNote
        )
    }

    /// Create command for creating a new comment for given upload id.
    func addComment(commentText: String, toUpload uploadId: String) -> Command {
        CreateCommentCommand.uploadComment(uploadId: uploadId, authorId: userId, text: commentText)
    }

    /// Updates the name for collaboration if it's different than the current name.
    func update(name: String, forCollaboration collaboration: Collaboration) -> Command? {
        guard name != collaboration.name else { return nil }
        return UpdateCollaborationNameCommand(collaborationId: collaboration.id, name: name)
    }

    /// Updates the completed state of note (comment)
    func toggleNoteCompleted(note: Comment) -> Command {
        let makeCompleted = !note.completed
        return UpdateNoteCompletedCommand(
            noteId: note.id,
            completedById: makeCompleted ? userId : nil,
            completedTimestamp: makeCompleted ? Date() : nil
        )
    }

    /// Updates the comment text if different than current.
    func update(text: String, forComment comment: Comment) -> Command? {
        guard text != comment.text else { return nil }
        return UpdateCommentTextCommand(commentId: comment.id, text: text)
    }

    /// Updates the due date for collaboration. If the provided due date is the same as the current one it returns no commands
    func update(dueDate: Date?, forCollaboration collaborationId: String) -> Command? {
        // the date has the selected day in project timezone, the time needs to be updated
        // to 23:59:59 (in project timezone) - the time might be different because there was
        // no due date and the current time was used, or the time was different in Firestore (which shouldn't happen?)
        let endOfDayDueDate: Date? = dueDate?._endOfDay(in: projectSummary.timeZone)
        guard let collaboration = mainRealm.object(ofType: Collaboration.self, forPrimaryKey: collaborationId),
              endOfDayDueDate != collaboration.dueDateTimestamp else { return nil }
        return UpdateCollaborationDueDateCommand(collaborationId: collaborationId, dueDateTimestamp: endOfDayDueDate)
    }

    /// Deletes given comment
    func delete(comment: Comment) -> Command {
        DeleteCommentCommand(commentId: comment.id)
    }

    /// Deletes given collaboration
    func delete(collaboration: Collaboration) -> Command {
        DeleteCollaborationCommand(collaborationId: collaboration.id)
    }

    func delete(collaborationId: String) -> Command {
        DeleteCollaborationCommand(collaborationId: collaborationId)
    }

    /// Delete upload with given id
    func delete(upload uploadId: String) -> Command {
        DeleteUploadCommand(uploadId: uploadId)
    }

    /// Updates the archivedTimestamp for geometry of given collaboration
    func toggleCollaborationArchived(collaboration: Collaboration) throws -> Command {
        guard let geometry = collaboration.geometry.first else {
            throw ModelError.geometryNotFound
        }
        let archive = geometry.archivedTimestamp == nil
        return UpdateGeometryArchivedCommand(
            collaborationId: collaboration.id,
            archivedTimestamp: archive ? Date() : nil
        )
    }

    func update(archived: Bool, forCollaboration collaborationId: String) -> Command {
        UpdateGeometryArchivedCommand(collaborationId: collaborationId, archivedTimestamp: archived ? Date() : nil)
    }

    /// Updates the status for collaboration if it's different than the current one.
    func update(status: Status, forCollaboration collaboration: Collaboration) -> Command? {
        guard status != collaboration.status else { return nil }
        return UpdateCollaborationStatusCommand(
            collaborationId: collaboration.id,
            statusId: status.id
        )
    }

    func update(status: Status, forCollaboration collaborationId: String) -> Command {
        UpdateCollaborationStatusCommand(collaborationId: collaborationId, statusId: status.id)
    }

    func update(assigneeId: String?, forCollaboration collaboration: Collaboration) -> Command? {
        guard assigneeId != collaboration.assignee?.id else { return nil }
        return UpdateCollaborationAssigneeCommand(
            collaborationId: collaboration.id,
            assigneeId: assigneeId
        )
    }

    func update(assigneeId: String?, forCollaboration collaborationId: String) -> Command {
        UpdateCollaborationAssigneeCommand(
            collaborationId: collaborationId,
            assigneeId: assigneeId
        )
    }

    /// Updates collaboration.description. If provided description is empty it's treated as nil (to remove the description in Firestore)
    func update(description: String?, forCollaboration collaboration: Collaboration) -> Command? {
        guard description != collaboration.collaborationDescription else { return nil }
        return UpdateCollaborationDescriptionCommand(
            collaborationId: collaboration.id,
            description: (description?.isEmpty ?? true) ? nil : description
        )
    }

    /// Updates upload.description. If provided description is empty it's treated as nil (to remove the description in Firestore)
    func update(description: String?, forUpload upload: Upload) -> Command? {
        guard description != upload.uploadDescription else { return nil }
        return UpdateUploadDescriptionCommand(
            authorId: userId,
            uploadId: upload.id,
            uploadDescription: (description?.isEmpty ?? true) ? nil : description
        )
    }

    func update(coordinates: CLLocationCoordinate2D, andCanvas canvas: Canvas,
                forCollaboration collaboration: Collaboration) throws -> Command
    {
        try UpdateGeometryLocationCommand(
            collaborationId: collaboration.id, canvasId: canvas.id, coordinates: coordinates
        )
    }

    /// Updates the annotations for Upload
    /// It generates the annotated image locally (if annotations provided) and schedules the upload of the annotated image
    /// Once this function finishes the annotated image is in localFiles
    @MainActor
    func update(annotations: Annotations?, forUpload upload: Upload) async throws -> Command? {
        let uploadId = upload.id
        // fetch image (should be already in cache)
        func fetchImageData() async throws -> Data {
            guard let mediaKey = MediaKey.mediaKey(projectId: projectId, upload: upload, annotated: false) else {
                throw "Failed to load the image"
            }
            let imageUrl = try await mediaCache.getCachedFileURL(forKey: mediaKey)
            return try Data(contentsOf: imageUrl)
        }
        // store annotated image in LocalFiles and schedule upload to Storage
        func storeAnnotatedImageData(_ data: Data) async throws -> MediaKey {
            // first store annotated image locally
            let annotatedMediaKey = MediaKey.localFilesKeyWithAutoStorageVersion(
                projectId: projectId,
                uploadId: upload.id,
                fileType: upload.fileType,
                annotated: true
            )
            try await localFiles.store(data, forKey: annotatedMediaKey)
            // store the thumbnail0, so it doesn't have to be fetched and is ready in offline mode
            try await localFiles.generateAndStoreThumbnails(data, forKey: annotatedMediaKey)

            // store the info about annotated image in LocalFiles
            // it has to be done before adding pending upload, as when the file is uploaded
            // the localStorageVersion will be replaced with the real one so we need the correct
            // order here
            // this will trigger the UI updates if listening for Upload changes (so the file needs
            // to be in LocalFiles already)
            try await write { realm in
                if let upload = realm.object(ofType: Upload.self, forPrimaryKey: uploadId) {
                    upload.localStorageVersion.setMainToLocalFile(
                        annotated: true,
                        generation: annotatedMediaKey.storageVersion
                    )
                }
            }
            return annotatedMediaKey
        }

        let imageData = try await fetchImageData()
        let annotatedImageData: Data
        if let annotations = annotations {
            guard let image = UIImage(data: imageData) else {
                throw "Failed to load the image"
            }
            // create annotated image
            annotatedImageData = AnnotationsRenderer.render(annotations: annotations, onImage: image)
        } else {
            // Annotated photo should be removed, but this requires support from server side,
            // so just upload non annotated as annotated for now
            annotatedImageData = imageData
        }
        let mediaKey = try await storeAnnotatedImageData(annotatedImageData)

        analytics?._trackProjectEvent(name: "photo annotated", self, [:])

        return UpdateUploadAnnotationsCommand(uploadId: uploadId, annotations: annotations, mediaKey: mediaKey)
    }

    /// Updates Collaboration.followers
    func update(followers: [String], forCollaboration collaborationId: String) -> Command {
        UpdateCollaborationFollowersCommand(collaborationId: collaborationId, followerIds: followers)
    }
}
