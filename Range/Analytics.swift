import Foundation
import Segment
import UIKit

/// global object for analytics access
var analytics: Segment.Analytics?

func setupAnalytics() {
    let runningTests = UserDefaults.standard.bool(forKey: "isTest")

    // only setup analytics if running the app and not tests
    if !runningTests {
        let config = Configuration(writeKey: "ioHVDkDzfasMREAU3crS2Nu1k8DH7fFd")
            .trackApplicationLifecycleEvents(false)
            .flushAt(3)
            .flushInterval(10)

        analytics = Analytics(configuration: config)
    }
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
