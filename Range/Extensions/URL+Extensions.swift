import Foundation
import UniformTypeIdentifiers

public extension URL {
    func _preferredFilenameExtension() -> String? {
        UTType(filenameExtension: pathExtension)?.preferredFilenameExtension
    }
}
