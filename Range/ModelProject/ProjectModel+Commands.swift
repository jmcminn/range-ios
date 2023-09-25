import CoreLocation
import Foundation
import Kingfisher
import OSLog
import RealmSwift
import Turf
import UIKit

// MARK: - run commands

extension ProjectModel {
    /// Run command locally and add an action for running in Firestore transaction.
    /// The Firestore transaction is queued by `PendingActionsModel` and not awaited here.
    func run(_ command: Command?) async throws {
        guard let command = command else { return }

        // Execute the command locally and store action for server side execution.
        // They both can fail. So first prepare the command for storage,  if it doesn't fail
        // then execute the local action and then store the action (this will not fail). So
        // local execution and storing for server side is "transactional".

        // 1. First prepare the action data (it might fail)
        let actionData = try pendingActionsModel.prepareAction(Action(projectId: projectId, command: command))

        // 2. Then apply the command in Realm (it might fail)
        try await write { realm in
            if let localCommand = command as? LocalCommand {
                try localCommand.apply(inRealm: realm)
            }
        }

        // 3. Store the action for server side execution (will not fail).
        pendingActionsModel.addAction(data: actionData)
    }

    /// A convenience wrapper for the `run` function that does the async call and catches and logs the error.
    /// It also accepts an optional callback which is invoked with the optional Error
    func run(_ command: Command?, callback: ((Error?) -> Void)?) {
        Task {
            do {
                try await run(command)
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
}

// MARK: - commands

extension ProjectModel {
    /// Adds given photos to pending uploads and returns command for:
    /// - creating all new tags and an upload with given tags and description and adding it to a collaboration
    /// Throws error if geometry with given id not found, or it has not feature with colllaboration
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
    ) async throws -> Command {
        guard let geometry = mainRealm.object(ofType: Geometry.self, forPrimaryKey: geometryId) else {
            throw ModelError.geometryNotFound
        }
        guard let feature = geometry.features.first else {
            throw ModelError.featureNotFound
        }
        guard let collaboration = feature.collaborations.first else {
            throw ModelError.collaborationNotFound
        }

        for photoToAdd in photosToAdd {
            try await pendingUploadsModel.addPendingUpload(forKey: photoToAdd.mediaKey)
            if let annotatedMediaKey = photoToAdd.annotatedMediaKey {
                try await pendingUploadsModel.addPendingUpload(forKey: annotatedMediaKey)
            }
        }

        return AddUploadsToCollaborationCommand(
            authorId: userId,
            collaborationId: collaboration.id,
            tags: tags.map(CommandTag.init(fromViewModel:)),
            uploadDescription: description,
            uploads: photosToAdd.map(CommandUpload.init(fromPhotoToAdd:))
        )
    }

    @MainActor
    func addMedia(_ data: Data, name: String, fileType: Upload.FileType,
                  toCollaboration collaboration: Collaboration) async throws -> Command
    {
        let uploadId = generateRealmId()
        let mediaKey = MediaKey.localFilesKey(projectId: projectId, uploadId: uploadId,
                                              fileType: fileType, annotated: false)

        try await localFiles.store(data, forKey: mediaKey)
        try await pendingUploadsModel.addPendingUpload(forKey: mediaKey)

        return AddUploadsToCollaborationCommand(
            authorId: userId,
            collaborationId: collaboration.id,
            tags: [],
            uploads: [CommandUpload(id: uploadId, fileType: fileType, fileSize: Int64(data.count), name: name)]
        )
    }

    /// Adds given photos to pending uploads and returns command for:
    /// - creating a new geometry of photoMarker type and adding it to given canvas.
    /// - creating a feature attached to this geometry and the collaboration attached to the feature.
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
        photosToAdd: [PhotoToAdd] = [],
        uploadTags: [TagViewModel] = [],
        uploadDescription: String? = nil
    ) async throws -> Command {
        for photoToAdd in photosToAdd {
            try await pendingUploadsModel.addPendingUpload(forKey: photoToAdd.mediaKey)
            if let annotatedMediaKey = photoToAdd.annotatedMediaKey {
                try await pendingUploadsModel.addPendingUpload(forKey: annotatedMediaKey)
            }
        }

        var status: Status?
        if isTask {
            guard let initialStatus = mainRealm.objects(Status.self).first(where: { $0.isInitial }) else {
                throw ModelError.statusNotFound
            }
            status = initialStatus
        }

        if let canvasSource = canvas.currentCanvasSource {
            // The canvas source is set if it's used in UI and can theoretically be null here
            // (although it shouldn't happen if user is adding a pin)
            analytics?.track(name: "collaboration created", properties: [
                "collaborationType": isTask ? "task" : "photo",
                "canvasType": canvasSource.type.rawValue,
            ])
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

    /// Create command for updating given Upload tags  (only if tags are different than existing ones).
    /// The command creates new tags.
    func update(tags: [TagViewModel], forUpload upload: Upload) -> Command? {
        let tagIdsSet = Set(tags.map(\.id))
        let existingTagIdsSet: Set<String> = Set(upload.tags.map(\.id))
        guard tagIdsSet != existingTagIdsSet else { return nil }

        return UpdateUploadsTagsCommand(
            uploadIds: [upload.id],
            tags: tags.map(CommandTag.init(fromViewModel:))
        )
    }

    /// Update mulitple uploads with given tags.
    /// If adding (add is `true`) then append the tags to current upload tags for each upload.
    /// If add is `false` then replace the current tags with the newly provided ones
    func update(tags: [TagViewModel], forUploads uploads: [String], add: Bool) -> Command {
        UpdateUploadsTagsCommand(uploadIds: uploads, tags: tags.map(CommandTag.init(fromViewModel:)), add: add)
    }

    /// Create command for updating given Collaboration tags (only if tags are different than existing ones).
    /// The command creates new tags.
    func update(tags: [TagViewModel], forCollaboration collaboration: Collaboration) -> Command? {
        let tagIdsSet = Set(tags.map(\.id))
        let existingTagIdsSet: Set<String> = Set(collaboration.tags.map(\.id))
        guard tagIdsSet != existingTagIdsSet else { return nil }

        return UpdateCollaborationsTagsCommand(
            collaborationIds: [collaboration.id],
            tags: tags.map(CommandTag.init(fromViewModel:))
        )
    }

    /// Update mulitple collaborations with given tags.
    /// If adding (add is `true`) then append the tags to current collaboration tags for each collaboration.
    /// If add is `false` then replace the current tags with the newly provided ones
    func update(tags: [TagViewModel], forCollaborations collaborations: [String], add: Bool) -> Command {
        UpdateCollaborationsTagsCommand(
            collaborationIds: collaborations,
            tags: tags.map(CommandTag.init(fromViewModel:)),
            add: add
        )
    }

    /// Create command for creating a new comment (or note if isNote = `true`) for given collaboration id.
    func addComment(commentText: String, isNote: Bool, toCollaboration collaborationId: String) -> Command {
        CreateCollaborationCommentCommand(
            commentId: generateRealmId(),
            collaborationId: collaborationId,
            authorId: userId,
            text: commentText,
            isNote: isNote
        )
    }

    /// Create command for creating a new comment for given upload id.
    func addComment(commentText: String, toUpload uploadId: String) -> Command {
        CreateUploadCommentCommand(
            commentId: generateRealmId(),
            uploadId: uploadId,
            authorId: userId,
            text: commentText
        )
    }

    /// Updates the name for collaboration if it's different than the current name.
    func update(name: String, forCollaboration collaboration: Collaboration) -> Command? {
        guard name != collaboration.name else { return nil }
        return UpdateCollaborationNameCommand(
            authorId: userId,
            collaborationId: collaboration.id,
            name: name
        )
    }

    /// Updates the completed state of note (comment)
    func toggleNoteCompleted(note: Comment) -> Command {
        let makeCompleted = !note.completed
        return UpdateNoteCompletedCommand(
            noteId: note.id,
            completedById: makeCompleted ? userId : nil
        )
    }

    /// Updates the comment text if different than current.
    func update(text: String, forComment comment: Comment) -> Command? {
        guard text != comment.text else { return nil }
        return UpdateCommentTextCommand(commentId: comment.id, text: text)
    }

    /// Updates the due date for collaboration. If the provided due date is the same as the current one it returns no commands
    func update(dueDate: Date?, forCollaboration collaboration: Collaboration) -> Command? {
        // the date has the selected day in project timezone, the time needs to be updated
        // to 23:59:59 (in project timezone) - the time might be different because there was
        // no due date and the current time was used, or the time was different in Firestore (which shouldn't happen?)
        let endOfDayDueDate: Date? = dueDate?._endOfDay(in: projectSummary.timeZone)
        guard endOfDayDueDate != collaboration.dueDateTimestamp else { return nil }
        return UpdateCollaborationsDueDateCommand(
            authorId: userId,
            collaborationIds: [collaboration.id],
            dueDateTimestamp: endOfDayDueDate
        )
    }

    /// Updates the due date for collaborations.
    func update(dueDate: Date?, forCollaborations collaborationIds: [String]) -> Command {
        // the date has the selected day in project timezone, the time needs to be updated
        // to 23:59:59 (in project timezone) - the time might be different because there was
        // no due date and the current time was used, or the time was different in Firestore (which shouldn't happen?)
        let endOfDayDueDate: Date? = dueDate?._endOfDay(in: projectSummary.timeZone)
        return UpdateCollaborationsDueDateCommand(
            authorId: userId,
            collaborationIds: collaborationIds,
            dueDateTimestamp: endOfDayDueDate
        )
    }

    /// Deletes given comment
    func delete(comment: Comment) -> Command {
        DeleteCommentCommand(commentId: comment.id)
    }

    /// Deletes given comment
    func delete(collaboration: Collaboration) throws -> Command {
        guard let geometry = collaboration.feature.first?.geometry.first else {
            throw ModelError.geometryNotFound
        }
        return DeleteCollaborationsCommand(geometryIds: [geometry.id], collaborationIds: [collaboration.id])
    }

    func delete(collaborations collaborationIds: [String]) -> Command {
        let geometryIds = [Collaboration](mainRealm.objects(Collaboration.self))
            .filter { collaborationIds.contains($0.id) }
            .compactMap { $0.feature.first?.geometry.first?.id }
        return DeleteCollaborationsCommand(geometryIds: geometryIds, collaborationIds: collaborationIds)
    }

    /// Delete uploads with given ids
    func delete(uploads: [String]) -> Command {
        DeleteUploadsCommand(uploadIds: uploads)
    }

    /// Updates the archivedTimestamp for geometry of given collaboration
    func toggleCollaborationArchived(collaboration: Collaboration) throws -> Command {
        guard let geometry = collaboration.feature.first?.geometry.first else {
            throw ModelError.geometryNotFound
        }
        let archive = geometry.archivedTimestamp == nil
        return UpdateGeometriesArchivedCommand(geometryIds: [geometry.id], archive: archive)
    }

    func update(archived: Bool, forCollaborations collaborationIds: [String]) -> Command {
        let geometryIds = [Collaboration](mainRealm.objects(Collaboration.self))
            .filter { collaborationIds.contains($0.id) }
            .compactMap { $0.feature.first?.geometry.first?.id }
        return UpdateGeometriesArchivedCommand(geometryIds: geometryIds, archive: archived)
    }

    /// Updates the status for collaboration if it's different than the current one.
    func update(status: Status, forCollaboration collaboration: Collaboration) -> Command? {
        guard status != collaboration.status else { return nil }
        return UpdateCollaborationsStatusCommand(
            authorId: userId,
            collaborationIds: [collaboration.id],
            statusId: status.id
        )
    }

    func update(status: Status, forCollaborations collaborationIds: [String]) -> Command {
        UpdateCollaborationsStatusCommand(authorId: userId, collaborationIds: collaborationIds, statusId: status.id)
    }

    /// Update status for given collaborations and mark given collaborations as archived (subset of collaborations to update the status)
    func update(status: Status,
                forCollaborations collaborationIds: [String],
                andArchiveCollaborations collaborationIdsToArchive: [String]) -> Command
    {
        let geometryIds = [Collaboration](mainRealm.objects(Collaboration.self))
            .filter { collaborationIdsToArchive.contains($0.id) }
            .compactMap { $0.feature.first?.geometry.first?.id }
        return UpdateCollaborationsStatusAndArchiveCommand(
            authorId: userId,
            geometryIds: geometryIds,
            collaborationIds: collaborationIds,
            statusId: status.id
        )
    }

    func update(assigneeId: String?, forCollaboration collaboration: Collaboration) -> Command? {
        guard assigneeId != collaboration.assignee?.id else { return nil }
        return UpdateCollaborationsAssigneeCommand(
            authorId: userId,
            collaborationIds: [collaboration.id],
            assigneeId: assigneeId
        )
    }

    func update(assigneeId: String?, forCollaborations collaborationIds: [String]) -> Command {
        UpdateCollaborationsAssigneeCommand(
            authorId: userId,
            collaborationIds: collaborationIds,
            assigneeId: assigneeId
        )
    }

    /// Updates collaboration.description. If provided description is empty it's treated as nil (to remove the description in Firestore)
    func update(description: String?, forCollaboration collaboration: Collaboration) -> Command? {
        guard description != collaboration.collaborationDescription else { return nil }
        return UpdateCollaborationDescriptionCommand(
            authorId: userId,
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
        guard let geometry = collaboration.feature.first?.geometry.first else {
            throw ModelError.geometryNotFound
        }
        return try UpdateGeometryLocationCommand(
            geometryId: geometry.id, canvasId: canvas.id, coordinates: coordinates
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
        func storeAnnotatedImageData(_ data: Data) async throws {
            // store the info about annotated image in LocalFiles
            // it has to be done before adding pending upload, as when the file is uploaded
            // the localStorageVersion will be replaced with the real one so we need the correct
            // order here
            try await write { realm in
                if let upload = realm.object(ofType: Upload.self, forPrimaryKey: uploadId) {
                    upload.localStorageVersion.setMainToLocalFile(annotated: true)
                }
            }
            // store annotated image locally and add to pending uploads
            let annotatedMediaKey = MediaKey.localFilesKey(
                projectId: projectId,
                uploadId: upload.id,
                fileType: upload.fileType,
                annotated: true
            )
            try await localFiles.store(data, forKey: annotatedMediaKey)
            try await pendingUploadsModel.addPendingUpload(forKey: annotatedMediaKey)
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
        try await storeAnnotatedImageData(annotatedImageData)

        return UpdateUploadAnnotationsCommand(uploadId: uploadId, annotations: annotations)
    }
}
