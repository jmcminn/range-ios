import Foundation

// possible errors for model
enum ModelError: Error, Equatable {
    case canvasCollectionNotFound
    case canvasNotFound
    case collaborationNotFound
    case commentNotFound
    case currentUserNotFound
    case featureNotFound
    case fieldNotSupported(_ field: String)
    case fileTypeNotSupported(_ type: String)
    case geometryNotFound
    case malformedUrl(_ url: String)
    case statusNotFound
    case summaryNotFound
    case uploadNotFound
    case userNotFound
}

// model error extension to provide localized descriptions of errors
extension ModelError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .canvasCollectionNotFound: return "Canvas collection not found"
        case .canvasNotFound: return "Canvas not found"
        case .collaborationNotFound: return "Collaboration not found"
        case .commentNotFound: return "Comment not found"
        case .currentUserNotFound: return "Couldn't load user data"
        case .featureNotFound: return "Feature not found"
        case let .fieldNotSupported(field): return "\(field) field not supported"
        case let .fileTypeNotSupported(type): return "\(type) fileType not supported"
        case .geometryNotFound: return "Geometry not found"
        case let .malformedUrl(url): return "Malformed URL: \(url)"
        case .statusNotFound: return "Status not found"
        case .summaryNotFound: return "Couldn't load project"
        case .uploadNotFound: return "Upload not found"
        case .userNotFound: return "User not found"
        }
    }
}
