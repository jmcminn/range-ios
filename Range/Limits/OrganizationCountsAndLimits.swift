// TODO: check local organization state based on PendingActions for all org projects?
class OrganizationCountsAndLimits {
    let userModel: UserModel
    let pendingActionsModel: PendingActionsModel

    var organization: Organization? {
        userModel.currentOrganizationModel?.organization
    }

    init(userModel: UserModel, pendingActionsModel: PendingActionsModel) {
        self.userModel = userModel
        self.pendingActionsModel = pendingActionsModel
    }

    // Check if Collaboration limits are still met.
    // Currently does not account for local-only (offline) data. So while offline you can add
    // infinite number of collaborations as long as the limits are not reached initially.
    func canAddCollaboration() -> Bool {
        guard let organization else { return false }

        guard let collaborationCount = organization.limitsAndCounts["collaborationCount"],
              let collaborationLimit = organization.limitsAndCounts["collaborationCountLimit"] else { return true }
        if collaborationCount >= collaborationLimit { return false }

        return true
    }

    // Check if Upload limits are still met.
    // Currently does not account for local-only (offline) data. So while offline you can add
    // infinite number of uploads as long as the limits are not reached initially.
    func canAddUpload() -> Bool {
        guard let organization else { return false }

        guard let uploadCount = organization.limitsAndCounts["uploadCount"],
              let uploadLimit = organization.limitsAndCounts["uploadCountLimit"] else { return true }
        if uploadCount >= uploadLimit { return false }

        guard let uploadStorageBytesCount = organization.limitsAndCounts["uploadStorageBytesCount"],
              let uploadStorageBytesLimit = organization.limitsAndCounts["uploadStorageBytesLimit"] else { return true }
        if uploadStorageBytesCount >= uploadStorageBytesLimit { return false }

        return true
    }
}
