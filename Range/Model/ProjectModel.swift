import Foundation

import CoreLocation
import UIKit

enum ProjectModel {
    /// Loads project.summary and canvases, doesn't load any other details yet
    // TODO: shouldn't return optional but rather throw?
    static func loadProject(id _: String) -> Project? {
        nil
    }
}

// TODO: separately load other details? in Project?

// protocol ProjectModel {}

// TODO: protocol vs Firebase impl
// class FirebaseProjectModel: ProjectModel {
//    /// Constant as this is a project model
//    fileprivate let projectId: String
//
//    /// Current canvas? non optional as we always preselect something?
////    var currentCanvas: Canvas
//
//    // photoMarker
//    // TODO: should it get all for project or only for canvas?
////    func observePhotoMarkers(canvas)
//
//    // TODO: (methods should be async?)
////    func addPhoto(_: UIImage, toCollaboration _: Collaboration) {}
////    func addPhoto(_: UIImage, at _: CLLocationCoordinate2D) {}
// }
