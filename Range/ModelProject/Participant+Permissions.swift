import Foundation

/// Extension of Participant to check the privileges and answer if given operation can be performed on given object
extension Participant {
    /// Only author or Admin can delete a collaboration
    func canDelete(_ collaboration: Collaboration) -> Bool {
        if organizationRole == .Admin { return true }
        if id == collaboration.author?.id { return true }
        return false
    }

    /// Only author or Admin can archive a collaboration
    func canArchive(_ collaboration: Collaboration) -> Bool {
        if organizationRole == .Admin { return true }
        if id == collaboration.author?.id { return true }
        return false
    }

    /// Only author or Admin can delete a comment
    func canDelete(_ comment: Comment) -> Bool {
        if organizationRole == .Admin { return true }
        if id == comment.author?.id { return true }
        return false
    }

    /// Only author or Admin can edit the text of a comment
    func canEditText(_ comment: Comment) -> Bool {
        if organizationRole == .Admin { return true }
        if id == comment.author?.id { return true }
        return false
    }

    /// Only author or Admin can delete an upload
    func canDelete(_ upload: Upload) -> Bool {
        if organizationRole == .Admin { return true }
        if id == upload.author?.id { return true }
        return false
    }
}
