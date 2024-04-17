import FirebaseFirestore
import Foundation
import RealmSwift

/// This enum exists only to help encoding different commands into JSON (to store the pending Action in the db = UserDefaults)
/// This is an implementation detail of pending actions model and might be replaced in the future with a direct way
/// of encoding the commands together with the info about the command type.
///
/// This will be encoded as for example:
///  {
///    "addUpdate": {
///     "_0": {
///         "updateId": "c4bb0672-6854-4e33-9c4e-f59f9425038a",
///         "parentId": "fb2e5d5b-997d-4740-b752-8ffb1a295462",
///         "parentType": "Collaboration",
///         "userId": "718d800c-0174-4128-9c5b-6e47a76d3c0e",
///        ...
///     }
///   }
/// }
/// Not ideal, the "_0" level is not really needed and is responsible for the unnamed command associated value but to get rid of it
/// there would have to be a custom codable implementation that switches over all the cases and does the manual encoded, decode.
/// Not ideal either but at least it's keyed by the enum cases...
enum ActionCommand: Codable {
    case addUploadsToCollaboration(AddUploadsToCollaborationCommand)
    case createCollaborationComment(CreateCollaborationCommentCommand)
    case createCollaboration(CreateCollaborationCommand)
    case createUploadComment(CreateUploadCommentCommand)
    case deleteCollaborations(DeleteCollaborationsCommand)
    case deleteComment(DeleteCommentCommand)
    case deleteUpload(DeleteUploadCommand)
    case updateCollaborationDescription(UpdateCollaborationDescriptionCommand)
    case updateCollaborationName(UpdateCollaborationNameCommand)
    case updateCollaborationsAssignee(UpdateCollaborationsAssigneeCommand)
    case updateCollaborationsDueDate(UpdateCollaborationsDueDateCommand)
    case updateCollaborationsStatus(UpdateCollaborationsStatusCommand)
    case updateCollaborationsStatusAndArchive(UpdateCollaborationsStatusAndArchiveCommand)
    case updateCollaborationsTags(UpdateCollaborationsTagsCommand)
    case updateCommentText(UpdateCommentTextCommand)
    case updateGeometriesArchived(UpdateGeometriesArchivedCommand)
    case updateGeometryLocation(UpdateGeometryLocationCommand)
    case updateNoteCompleted(UpdateNoteCompletedCommand)
    case updateUploadAnnotations(UpdateUploadAnnotationsCommand)
    case updateUploadDescription(UpdateUploadDescriptionCommand)
    case updateUploadsTags(UpdateUploadsTagsCommand)

    init(_ c: Any) {
        switch c {
        case let c as AddUploadsToCollaborationCommand: self = .addUploadsToCollaboration(c)
        case let c as CreateCollaborationCommentCommand: self = .createCollaborationComment(c)
        case let c as CreateCollaborationCommand: self = .createCollaboration(c)
        case let c as CreateUploadCommentCommand: self = .createUploadComment(c)
        case let c as DeleteCollaborationsCommand: self = .deleteCollaborations(c)
        case let c as DeleteCommentCommand: self = .deleteComment(c)
        case let c as DeleteUploadCommand: self = .deleteUpload(c)
        case let c as UpdateCollaborationDescriptionCommand: self = .updateCollaborationDescription(c)
        case let c as UpdateCollaborationNameCommand: self = .updateCollaborationName(c)
        case let c as UpdateCollaborationsAssigneeCommand: self = .updateCollaborationsAssignee(c)
        case let c as UpdateCollaborationsDueDateCommand: self = .updateCollaborationsDueDate(c)
        case let c as UpdateCollaborationsStatusCommand: self = .updateCollaborationsStatus(c)
        case let c as UpdateCollaborationsStatusAndArchiveCommand: self = .updateCollaborationsStatusAndArchive(c)
        case let c as UpdateCollaborationsTagsCommand: self = .updateCollaborationsTags(c)
        case let c as UpdateCommentTextCommand: self = .updateCommentText(c)
        case let c as UpdateGeometriesArchivedCommand: self = .updateGeometriesArchived(c)
        case let c as UpdateGeometryLocationCommand: self = .updateGeometryLocation(c)
        case let c as UpdateNoteCompletedCommand: self = .updateNoteCompleted(c)
        case let c as UpdateUploadAnnotationsCommand: self = .updateUploadAnnotations(c)
        case let c as UpdateUploadDescriptionCommand: self = .updateUploadDescription(c)
        case let c as UpdateUploadsTagsCommand: self = .updateUploadsTags(c)
        default: fatalError("ActionCommand not implemented for \(c)")
        }
    }

    var localCommand: LocalCommand {
        switch self {
        case let .addUploadsToCollaboration(c): return c
        case let .createCollaborationComment(c): return c
        case let .createCollaboration(c): return c
        case let .createUploadComment(c): return c
        case let .deleteCollaborations(c): return c
        case let .deleteComment(c): return c
        case let .deleteUpload(c): return c
        case let .updateCollaborationDescription(c): return c
        case let .updateCollaborationName(c): return c
        case let .updateCollaborationsAssignee(c): return c
        case let .updateCollaborationsDueDate(c): return c
        case let .updateCollaborationsStatus(c): return c
        case let .updateCollaborationsStatusAndArchive(c): return c
        case let .updateCollaborationsTags(c): return c
        case let .updateCommentText(c): return c
        case let .updateGeometriesArchived(c): return c
        case let .updateGeometryLocation(c): return c
        case let .updateNoteCompleted(c): return c
        case let .updateUploadAnnotations(c): return c
        case let .updateUploadDescription(c): return c
        case let .updateUploadsTags(c): return c
        }
    }

    var firestoreCommand: FirestoreCommand? {
        switch self {
        case let .addUploadsToCollaboration(c): return c
        case let .createCollaborationComment(c): return c
        case let .createUploadComment(c): return c
        case let .deleteCollaborations(c): return c
        case let .updateCollaborationDescription(c): return c
        case let .updateCollaborationName(c): return c
        case let .updateCollaborationsAssignee(c): return c
        case let .updateCollaborationsDueDate(c): return c
        case let .updateCollaborationsStatus(c): return c
        case let .updateCollaborationsStatusAndArchive(c): return c
        case let .updateCollaborationsTags(c): return c
        case let .updateCommentText(c): return c
        case let .updateGeometriesArchived(c): return c
        case let .updateGeometryLocation(c): return c
        case let .updateNoteCompleted(c): return c
        case let .updateUploadAnnotations(c): return c
        case let .updateUploadDescription(c): return c
        case let .updateUploadsTags(c): return c
        default: return nil
        }
    }

    var firebaseFunctionCommand: FirebaseFunctionCommand? {
        switch self {
        case let .createCollaboration(c): return c
        case let .deleteComment(c): return c
        case let .deleteUpload(c): return c
        default: return nil
        }
    }
}
