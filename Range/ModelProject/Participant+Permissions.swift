import Foundation

/// Extension of Participant to check the privileges and answer if given operation can be performed on given object
extension Participant {
    /// Only organization Admin can create a project
    func canCreateProject() -> Bool {
        guard !self.isInvalidated else { return false }
        return organizationRole == .Admin
    }
    
    func canDeleteProject() -> Bool {
        guard !self.isInvalidated else { return false }
        return organizationRole == .Admin
    }
    
    func canArchiveProject() -> Bool {
        guard !self.isInvalidated else { return false }
        return organizationRole == .Admin
    }
    
    /// Guest cannot create a collaboration
    func canCreateCollaboration() -> Bool {
        guard !self.isInvalidated else { return false }
        if organizationRole == .Admin || organizationRole == .Collaborator { return true }
        return false
    }

    /// Only Collaboratora author or Admin can delete a collaboration
    func canDelete(_ collaboration: Collaboration) -> Bool {
        guard !self.isInvalidated else { return false }
        switch organizationRole {
        case .Admin: return true
        case .Collaborator: return id == collaboration.author?.id
        case .Guest: return false
        case .Unknown: return false
        }
    }

    /// Only Collaborator or Admin can archive a collaboration
    func canArchive(_ collaboration: Collaboration) -> Bool {
        guard !self.isInvalidated else { return false }
        if organizationRole == .Admin || organizationRole == .Collaborator { return true }
        return false
    }

    /// Guest cannot complete or uncomplete a task
    func canCompleteTasks() -> Bool {
        guard !self.isInvalidated else { return false }
        if organizationRole == .Admin || organizationRole == .Collaborator { return true }
        return false
    }

    /// Only author or Admin can delete a comment
    func canDelete(_ comment: Comment) -> Bool {
        guard !self.isInvalidated else { return false }
        if organizationRole == .Admin { return true }
        if id == comment.author?.id { return true }
        return false
    }

    /// Only author or Admin can edit the text of a comment
    func canEditText(_ comment: Comment) -> Bool {
        guard !self.isInvalidated else { return false }
        if organizationRole == .Admin { return true }
        if id == comment.author?.id { return true }
        return false
    }

    /// Only author or Admin can delete an upload
    func canDelete(_ upload: Upload) -> Bool {
        guard !self.isInvalidated else { return false }
        if organizationRole == .Admin { return true }
        if id == upload.author?.id { return true }
        return false
    }
}
