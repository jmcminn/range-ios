import Foundation
import OSLog

/// Extending logger to provide app-wide loggers for different categories
extension Logger {
    /// subsystem to be used by all loggers in the app
    private static var subsystem = Bundle.main.bundleIdentifier!

    /// analytics related logs
    static let analytics = Logger(subsystem: subsystem, category: "analytics")
    /// photo annotations related logs
    static let annotations = Logger(subsystem: subsystem, category: "annotations")
    /// App assets related logs (errors loading images)
    static let assets = Logger(subsystem: subsystem, category: "assets")
    /// authentication logs
    static let auth = Logger(subsystem: subsystem, category: "auth")
    /// cache
    static let cache = Logger(subsystem: subsystem, category: "cache")
    /// camera
    static let camera = Logger(subsystem: subsystem, category: "camera")
    /// Firebase sync related logs
    static let firebase = Logger(subsystem: subsystem, category: "firebase")
    /// Firestore sync related logs
    static let firestore = Logger(subsystem: subsystem, category: "firestore")
    /// Firebase functions related logs
    static let functions = Logger(subsystem: subsystem, category: "functions")
    /// knock logs
    static let knock = Logger(subsystem: subsystem, category: "knock")
    /// Everything mapbox
    static let mapbox = Logger(subsystem: subsystem, category: "mapbox")
    /// Internal model (Realm based) logs
    static let model = Logger(subsystem: subsystem, category: "model")
    /// pending actions related logs
    static let pendingActions = Logger(subsystem: subsystem, category: "actions")
    /// push notifications related logs
    static let pushNotifications = Logger(subsystem: subsystem, category: "notifications")
    /// Logs related to sentry configuration
    static let sentry = Logger(subsystem: subsystem, category: "sentry")
    /// Logs related to settings
    static let settings = Logger(subsystem: subsystem, category: "settings")
    /// Cloud Storage sync related logs
    static let storage = Logger(subsystem: subsystem, category: "storage")
    /// anything UI related
    static let ui = Logger(subsystem: subsystem, category: "ui")
}
