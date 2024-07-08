import AppcuesKit
import Foundation
import OSLog
import Segment
import SegmentAppcues
import UIKit

/// global object for analytics access
var analytics: Segment.Analytics?

extension AppcuesDestination {
    // Creating a shared reference to this destination will allow us to access the underlying
    // Appcues SDK in other areas of the code.  This enables access to any additional SDK
    // functionality desired, like the Debugger
    static var shared = AppcuesDestination()
}

func setupAnalytics() {
    let runningTests = UserDefaults.standard.bool(forKey: "isTest")
    guard !runningTests else {
        // only setup analytics if running the app and not tests
        return
    }

    guard let segmentKey: String = try? AppConfiguration.value(for: "SegmentKey"), segmentKey.isEmpty == false else {
        Logger.analytics.debug("No segment key provided! Not starting analytics")
        return
    }

    let config = Configuration(writeKey: segmentKey)
        .trackApplicationLifecycleEvents(false)
        .flushAt(3)
        .flushInterval(10)

    analytics = Analytics(configuration: config)

    // the only way to add data to event context is to use a plugin
    analytics!.add(plugin: CustomizeAllTrackCalls())

    // only init Appcues when the application id is provided (it's not actually used here, only
    // for handling links which is needed only for flows debugging, but it's used as marker
    // to mark the environments we want to enable Appcue in)
    if let appcuesAppId: String = try? AppConfiguration.value(for: "AppcuesApplicationId"), !appcuesAppId.isEmpty {
        analytics!.add(plugin: AppcuesDestination.shared)
    }
}

class CustomizeAllTrackCalls: Segment.EventPlugin {
    let type: Segment.PluginType = .enrichment
    var analytics: Segment.Analytics?

    /// Customize tracked events. If the event has a "groupId" property, add it also to "context" (groupId has to be in context for the group to be recognized)
    public func track(event: TrackEvent) -> TrackEvent? {
        var workingEvent = event
        if let groupId: String = event.properties?.value(forKeyPath: "groupId") {
            do {
                workingEvent.context = try workingEvent.context?.add(value: groupId, forKey: "groupId")
            } catch {
                Logger.analytics.error("Couldn't add groupId to track event context: \(error, privacy: .public)")
            }
        }
        return workingEvent
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
    
    func _trackOrganizationEvent(name: String, _ model: OrganizationModel, _ props: [String: String]) {
        let properties = [
            "userId": model.user.id,
            "groupId": model.organizationId,
            "organizationRole": model.currentUser.organizationRole.rawValue,
            "platform": UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone",
        ].merging(props) { _, new in new }

        track(name: name, properties: properties)
    }
}
