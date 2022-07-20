import FirebaseFirestore
import Foundation

extension DocumentChangeType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .added: return "added"
        case .removed: return "removed"
        case .modified: return "modified"
        }
    }
}
