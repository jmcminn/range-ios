import Foundation
import OSLog

/// Extending logger to provide app-wide loggers for different categories
extension Logger {
    /// subsystem to be used by all loggers in the app
    private static var subsystem = Bundle.main.bundleIdentifier!

    /// App assets related logs (errors loading images)
    static let assets = Logger(subsystem: subsystem, category: "assets")
    /// authentication logs
    static let auth = Logger(subsystem: subsystem, category: "auth")
    /// camera
    static let camera = Logger(subsystem: subsystem, category: "camera")
    /// Everything mapbox
    static let mapbox = Logger(subsystem: subsystem, category: "mapbox")
    /// Internal model (Realm based) logs
    static let model = Logger(subsystem: subsystem, category: "model")
    /// Firebase sync related logs
    static let firebase = Logger(subsystem: subsystem, category: "firebase")
    /// Firestore sync related logs
    static let firestore = Logger(subsystem: subsystem, category: "firestore")
    /// anything UI related
    static let ui = Logger(subsystem: subsystem, category: "ui")
}
