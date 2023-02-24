import CoreLocation
import Foundation
import Kingfisher
import OSLog
import RealmSwift
import Turf

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
            try await pendingUploadsModel
                .addPendingUpload(forKey: MediaKey(projectId: projectId, uploadId: photoToAdd.uploadId,
                                                   fileType: .jpeg))
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
        let mediaKey = MediaKey(projectId: projectId, uploadId: uploadId, fileType: fileType)

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
    ///     - photosToAdd: the data for the images to add
    ///     - tags: array of tags, existing or new ones
    ///     - description: upload description
    ///     - coordinates: the coordinates for the photo marker
    ///     - canvas: should be from the `mainRealm`
    ///     - geometryId: this id will be used for the newly created geometry
    @MainActor
    func createCollaboration(
        at coordinates: CLLocationCoordinate2D,
        in canvas: PDFCanvas,
        withGeometryId geometryId: String,
        isTask: Bool,
        photosToAdd: [PhotoToAdd] = [],
        uploadTags: [TagViewModel] = [],
        uploadDescription: String? = nil
    ) async throws -> Command {
        for photoToAdd in photosToAdd {
            try await pendingUploadsModel.addPendingUpload(forKey: MediaKey(
                projectId: projectId,
                uploadId: photoToAdd.uploadId,
                fileType: .jpeg
            ))
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
            uploadTags: uploadTags.map(CommandTag.init(fromViewModel:)),
            uploadDescription: uploadDescription,
            uploads: photosToAdd.map(CommandUpload.init(fromPhotoToAdd:)),
            statusId: status?.id
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

        return UpdateUploadTagsCommand(
            uploadId: upload.id,
            tags: tags.map(CommandTag.init(fromViewModel:))
        )
    }

    /// Create command for updating given Collaboration tags (only if tags are different than existing ones).
    /// The command creates new tags.
    func update(tags: [TagViewModel], forCollaboration collaboration: Collaboration) -> Command? {
        let tagIdsSet = Set(tags.map(\.id))
        let existingTagIdsSet: Set<String> = Set(collaboration.tags.map(\.id))
        guard tagIdsSet != existingTagIdsSet else { return nil }

        return UpdateCollaborationTagsCommand(
            collaborationId: collaboration.id,
            tags: tags.map(CommandTag.init(fromViewModel:))
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
        return UpdateCollaborationDueDateCommand(
            authorId: userId,
            collaborationId: collaboration.id,
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
        return DeleteCollaborationCommand(geometryId: geometry.id, collaborationId: collaboration.id)
    }

    func delete(upload: Upload) -> Command {
        DeleteUploadCommand(uploadId: upload.id)
    }

    /// Updates the archivedTimestamp for geometry of given collaboration
    func toggleCollaborationArchived(collaboration: Collaboration) throws -> Command {
        guard let geometry = collaboration.feature.first?.geometry.first else {
            throw ModelError.geometryNotFound
        }
        let archive = geometry.archivedTimestamp == nil
        return UpdateGeometryArchivedCommand(geometryId: geometry.id, archive: archive)
    }

    /// Updates the status for collaboration if it's different than the current one.
    func update(status: Status, forCollaboration collaboration: Collaboration) -> Command? {
        guard status != collaboration.status else { return nil }
        return UpdateCollaborationStatusCommand(
            authorId: userId,
            collaborationId: collaboration.id,
            statusId: status.id
        )
    }

    func update(assignee: Participant?, forCollaboration collaboration: Collaboration) -> Command? {
        guard assignee != collaboration.assignee else { return nil }
        return UpdateCollaborationAssigneeCommand(
            authorId: userId,
            collaborationId: collaboration.id,
            assigneeId: assignee?.id
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

    func update(coordinates: CLLocationCoordinate2D, andCanvas canvas: PDFCanvas,
                forCollaboration collaboration: Collaboration) throws -> Command
    {
        guard let geometry = collaboration.feature.first?.geometry.first else {
            throw ModelError.geometryNotFound
        }
        return try UpdateGeometryLocationCommand(
            geometryId: geometry.id, canvasId: canvas.id, coordinates: coordinates
        )
    }
}
