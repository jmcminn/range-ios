import Foundation
import RealmSwift

/// Utilities for Upload.storageVersion
extension Map<String, String> {
    func updateFromFirestore(_ storageVersion: [String: String]?) {
        // Realm doesn't allow for '.' in dictionary key, so storageVersion cannot use "annotated.thumbnail0" for example
        // Replace '.' with '_'
        let storageVersion = storageVersion?.reduce(into: [:]) { result, elem in
            result[elem.key.replacingOccurrences(of: ".", with: "_")] = elem.value
        }
        if let storageVersion = storageVersion {
            // merge overwriting with new values
            merge(storageVersion) { _, new in new }
        }
    }

    static func map(withFirestoreStorageVersion storageVersion: [String: String]?) -> Map<String, String> {
        let result = Map()
        result.updateFromFirestore(storageVersion)
        return result
    }

    func getMain(annotated: Bool) -> String? {
        self[annotated ? "annotated" : "main"]
    }

    /// `local` option adds a "local" prefix to value to mark this file as local
    func setMain(annotated: Bool, value: String, local: Bool) {
        setValue(local ? "local_\(value)" : value, forKey: annotated ? "annotated" : "main")
    }

    func get(annotated: Bool, thumbnail: Int) -> String? {
        annotated
            ? self["annotated_thumbnail\(thumbnail)"]
            : self["thumbnail\(thumbnail)"]
    }
}
