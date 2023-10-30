import Foundation
import RealmSwift

/// Check if the version was created for localFile using the `setMainToLocalFile`
func _isStorageVersionLocalFile(version: String) -> Bool {
    version.starts(with: "localFile")
}

/// Assuming that it's a local file storage version, return the generation (after the "localFile_" prefix)
func _getLocalFileStorageVersionGeneration(version: String) -> String {
    String(version.dropFirst("localFile_".count))
}

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

    func setMain(annotated: Bool, value: String) {
        setValue(value, forKey: annotated ? "annotated" : "main")
    }

    /// Sets the main value as a `localFile_<generation>`  where `localFile` is a prefix meaning that this file is in LocalFiles
    /// and generation is a locally generated `generation` (a timestamp)
    func setMainToLocalFile(annotated: Bool, generation: String) {
        setValue("localFile_\(generation)", forKey: annotated ? "annotated" : "main")
    }

    func set(annotated: Bool, thumbnail: Int, value: String) {
        if annotated {
            setValue(value, forKey: "annotated_thumbnail\(thumbnail)")
        } else {
            setValue(value, forKey: "thumbnail\(thumbnail)")
        }
    }

    func get(annotated: Bool, thumbnail: Int) -> String? {
        annotated
            ? self["annotated_thumbnail\(thumbnail)"]
            : self["thumbnail\(thumbnail)"]
    }
}
