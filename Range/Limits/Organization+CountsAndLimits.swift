// TODO: check local organization state based on PendingActions for all org projects?
extension Organization {
    
    
    // Check if Collaboration limits are still met.
    // Currently does not account for local-only (offline) data. So while offline you can add
    // infinite number of collaborations as long as the limits are not reached initially.
    func canAddCollaboration() -> Bool {
        guard let collaborationCount = limitsAndCounts["collaborationCount"],
              let collaborationLimit = limitsAndCounts["collaborationCountLimit"] else { return true }
        if collaborationCount >= collaborationLimit { return false }
        
        return true
    }
    
    // Check if Upload limits are still met.
    // Currently does not account for local-only (offline) data. So while offline you can add
    // infinite number of uploads as long as the limits are not reached initially.
    func canAddUpload() -> Bool {
        guard let uploadCount = limitsAndCounts["uploadCount"],
              let uploadLimit = limitsAndCounts["uploadCountLimit"] else { return true }
        if uploadCount >= uploadLimit { return false }

        guard let uploadStorageBytesCount = limitsAndCounts["uploadStorageBytesCount"],
              let uploadStorageBytesLimit = limitsAndCounts["uploadStorageBytesLimit"] else { return true }
        if uploadStorageBytesCount >= uploadStorageBytesLimit { return false }

        return true
    }
}
