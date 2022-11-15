import CoreLocation
import Foundation
import Kingfisher
import RealmSwift
import Turf

/// convenience function for generating new realm id
func generateRealmId() -> String {
    UUID().uuidString.lowercased()
}

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
            try await pendingUploadsModel.addPendingUpload(key: photoToAdd.cacheKey)
        }

        return AddUploadsToCollaborationCommand(
            authorId: userId,
            collaborationId: collaboration.id,
            tags: tags.map(CommandTag.init(fromViewModel:)),
            uploadDescription: description,
            uploads: photosToAdd.map(CommandUpload.init(fromPhotoToAdd:))
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
    func createPhotoCollaboration(
        _ photosToAdd: [PhotoToAdd],
        tags: [TagViewModel],
        description: String,
        at coordinates: CLLocationCoordinate2D,
        in canvas: PDFCanvas,
        withGeometryId geometryId: String
    ) async throws -> Command {
        for photoToAdd in photosToAdd {
            try await pendingUploadsModel.addPendingUpload(key: photoToAdd.cacheKey)
        }

        return CreatePhotoCollaborationCommand(
            authorId: userId,
            canvasId: canvas.id,
            geometryId: geometryId,
            coordinates: coordinates,
            tags: tags.map(CommandTag.init(fromViewModel:)),
            uploadDescription: description,
            uploads: photosToAdd.map(CommandUpload.init(fromPhotoToAdd:))
        )
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
}
