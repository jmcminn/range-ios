class OrganizationLimitsAndCounts {
    let userModel: UserModel
    let pendingActionsModel: PendingActionsModel

    var organization: Organization? {
        userModel.currentOrganizationModel?.organization
    }

    init(userModel: UserModel, pendingActionsModel: PendingActionsModel) {
        self.userModel = userModel
        self.pendingActionsModel = pendingActionsModel
    }
    
    // Check if Project limits are still met.
    // The current project count is take from Organization.projects (there's no projectCount maintained)
    func canAddProject() -> Bool {
        guard let organization else { return false }
        guard let projectLimit = organization.limitsAndCounts["projectCountLimit"] else { return true }

        let projectCount = organization.projectIds.count
        
        if projectCount >= projectLimit { return false }
        
        return true
    }

    // Check if Collaboration limits are still met.
    // Checks the current count reported by organization and number of pending (local) collaborations
    func canAddCollaboration() -> Bool {
        guard let organization else { return false }

        guard let collaborationCount = organization.limitsAndCounts["collaborationCount"],
              let collaborationLimit = organization.limitsAndCounts["collaborationCountLimit"] else { return true }

        let pendingCollaborationCreates = Int64(pendingActionsModel
            .getCollaborationCreatesCount(forProjectIds: Array(organization.projectIds)))

        if collaborationCount + pendingCollaborationCreates >= collaborationLimit { return false }

        return true
    }

    // Check if Upload limits are still met.
    // Checks the current count reported by organization and number of pending (local) uploads
    func canAddUpload() -> Bool {
        guard let organization else { return false }

        guard let uploadCount = organization.limitsAndCounts["uploadCount"],
              let uploadLimit = organization.limitsAndCounts["uploadCountLimit"] else { return true }

        let pendingUploadCreates = Int64(pendingActionsModel
            .getUploadCreatesCount(forProjectIds: Array(organization.projectIds)))

        if uploadCount + pendingUploadCreates >= uploadLimit { return false }

        guard let uploadStorageBytesCount = organization.limitsAndCounts["uploadStorageBytesCount"],
              let uploadStorageBytesLimit = organization.limitsAndCounts["uploadStorageBytesLimit"] else { return true }
        if uploadStorageBytesCount >= uploadStorageBytesLimit { return false }

        return true
    }
}
