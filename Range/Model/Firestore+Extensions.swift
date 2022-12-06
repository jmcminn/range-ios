import FirebaseFirestore
import Foundation

/// Extension for better logging.
extension DocumentChangeType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .added: return "added"
        case .removed: return "removed"
        case .modified: return "modified"
        }
    }
}
