import Foundation
import MapboxMaps

extension MapboxMaps.ViewportStatus {
    /// Whether this viewport status is currently in follow me mode or is transitioning to follow me mode
    var _isOrTransitionsToFollowMeMode: Bool {
        if case let .state(state) = self, state is FollowPuckViewportState {
            return true
        } else if case let .transition(_, toState) = self, toState is FollowPuckViewportState {
            return true
        } else {
            return false
        }
    }
}
