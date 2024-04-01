import Foundation

/// Defines annotation types supported by Range iOS app
enum AnnotationType: String, Codable {
    case scribble, text, arrow, line
}

/// The name for the notification posted in NotificationCenter when the annotation changes
let AnnotationUpdateNotificationName = Notification.Name("io.range.App.AnnotationChanged")

/// "Abstract"  parent for all annotation models.
/// Swift doesn't support abstract classes so it's just a normal class with some functions not implemented (to be implemented by subclasses)
class Annotation: NSObject, NSCopying, Codable, ObservableObject {
    /// The unique id of the annotation
    let id: String
    /// Type, it's not `let` so it's encoded/decoded
    let type: AnnotationType

    init(id: String = UUID().uuidString.lowercased(), type: AnnotationType) {
        self.id = id
        self.type = type
    }

    /// Exact copy of the annotation (including the id)
    func copy(with _: NSZone? = nil) -> Any {
        fatalError("copy to be provided by subclasses")
    }

    override public var hash: Int {
        var hasher = Hasher()
        hasher.combine(id)
        return hasher.finalize()
    }

    /// A duplicate is a copy that has a different id and is offset by given (x,y)
    func duplicate(withOffset _: CGPoint) -> Annotation {
        fatalError("duplicate to be provided by subclasses")
    }

    /// Use notification center to post the notification about update in filters
    func postUpdate() {
        NotificationCenter.default.post(name: AnnotationUpdateNotificationName, object: id)
    }
}
