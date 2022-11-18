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
    case createCollaborationComment(_ command: CreateCollaborationCommentCommand)
    case createPhotoCollaboration(CreatePhotoCollaborationCommand)
    case deleteCollaboration(DeleteCollaborationCommand)
    case deleteComment(DeleteCommentCommand)
    case updateCollaborationDueDate(_ command: UpdateCollaborationDueDateCommand)
    case updateCollaborationName(_ command: UpdateCollaborationNameCommand)
    case updateCollaborationTags(_ command: UpdateCollaborationTagsCommand)
    case updateCommentText(_ command: UpdateCommentTextCommand)
    case updateNoteCompleted(_ command: UpdateNoteCompletedCommand)
    case updateUploadTags(_ command: UpdateUploadTagsCommand)

    init(_ c: Any) {
        switch c {
        case let c as AddUploadsToCollaborationCommand: self = .addUploadsToCollaboration(c)
        case let c as CreateCollaborationCommentCommand: self = .createCollaborationComment(c)
        case let c as CreatePhotoCollaborationCommand: self = .createPhotoCollaboration(c)
        case let c as DeleteCollaborationCommand: self = .deleteCollaboration(c)
        case let c as DeleteCommentCommand: self = .deleteComment(c)
        case let c as UpdateCollaborationDueDateCommand: self = .updateCollaborationDueDate(c)
        case let c as UpdateCollaborationNameCommand: self = .updateCollaborationName(c)
        case let c as UpdateCollaborationTagsCommand: self = .updateCollaborationTags(c)
        case let c as UpdateCommentTextCommand: self = .updateCommentText(c)
        case let c as UpdateNoteCompletedCommand: self = .updateNoteCompleted(c)
        case let c as UpdateUploadTagsCommand: self = .updateUploadTags(c)
        default: fatalError("ActionCommand not implemented for \(c)")
        }
    }

    var firestoreCommand: FirestoreCommand {
        switch self {
        case let .addUploadsToCollaboration(c): return c
        case let .createCollaborationComment(c): return c
        case let .createPhotoCollaboration(c): return c
        case let .deleteCollaboration(c): return c
        case let .deleteComment(c): return c
        case let .updateCollaborationDueDate(c): return c
        case let .updateCollaborationName(c): return c
        case let .updateCollaborationTags(c): return c
        case let .updateCommentText(c): return c
        case let .updateNoteCompleted(c): return c
        case let .updateUploadTags(c): return c
        }
    }
}
