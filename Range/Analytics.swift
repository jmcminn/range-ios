import Foundation
import OSLog
import Segment
import UIKit

/// global object for analytics access
var analytics: Segment.Analytics?

func setupAnalytics() {
    let runningTests = UserDefaults.standard.bool(forKey: "isTest")
    guard !runningTests else {
        // only setup analytics if running the app and not tests
        return
    }

    guard let segmentKey: String = try? AppConfiguration.value(for: "SegmentKey"), segmentKey.isEmpty == false else {
        Logger.settings.debug("No segment key provided! Not starting analytics")
        return
    }

    let config = Configuration(writeKey: segmentKey)
        .trackApplicationLifecycleEvents(false)
        .flushAt(3)
        .flushInterval(10)

    analytics = Analytics(configuration: config)
}

extension Analytics {
    func _trackProjectEvent(name: String, _ model: ProjectModel, _ props: [String: String]) {
        let properties = [
            "userId": model.userId,
            "groupId": model.projectSummary.organizationId,
            "organizationRole": model.currentUser.organizationRole.rawValue,
            "platform": UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone",
            "canvasType": model.currentCanvas.currentCanvasSource.type.rawValue,
        ].merging(props) { _, new in new }

        track(name: name, properties: properties)
    }
}
