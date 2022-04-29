import Foundation
import QuartzCore
import UIKit

/// Wrapper class for CADisplayLink that accepts the handler function for display link target.
@objc class DisplayLink: NSObject {
    var caDisplayLink: CADisplayLink?

    /// Display link handler called with `dt` - delta of time since last called and `t` - total time since added to the run loop.
    typealias DisplayLinkHandler = (Double, Double) -> Void
    /// Will be synced with display link.
    private let handler: DisplayLinkHandler
    /// Last time the handler was called
    private var lastTimeStamp: Double?
    /// First time the handler was called after display link added to the run loop
    private var initialTimeStamp: Double?

    init(handler: @escaping (Double, Double) -> Void) {
        self.handler = handler

        super.init()

        caDisplayLink = CADisplayLink(target: self,
                                      selector: #selector(displayLinkCallback(displaylink:)))

        caDisplayLink?.add(to: .current, forMode: .common)

        NotificationCenter.default.addObserver(self, selector: #selector(willResignActive),
                                               name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActive),
                                               name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    /// CADisplayLink callback
    @objc private func displayLinkCallback(displaylink: CADisplayLink) {
        let timeStamp = displaylink.timestamp
        guard let lastTimeStamp = lastTimeStamp else {
            self.lastTimeStamp = timeStamp
            return
        }
        guard let initialTimeStamp = initialTimeStamp else {
            self.initialTimeStamp = timeStamp
            return
        }

        let dt = max(timeStamp - lastTimeStamp, 0)
        self.lastTimeStamp = timeStamp

        handler(dt, timeStamp - initialTimeStamp)
    }

    /// Invalidate the CADisplayLink
    func invalidate() {
        caDisplayLink?.invalidate()
        lastTimeStamp = nil
        initialTimeStamp = nil
    }

    @objc private func willResignActive() {
        caDisplayLink?.isPaused = true
        lastTimeStamp = nil
    }

    @objc private func didBecomeActive() {
        lastTimeStamp = nil
        caDisplayLink?.isPaused = false
    }
}
