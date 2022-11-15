import Firebase
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import FirebaseStorage
import OSLog
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        initiateFirebase()

        return true
    }

    private func initiateFirebase() {
        // firebase emulator enabled in the "Debug firebase emulator" configuration
        // in the `FIREBASE_PROJECT` custom build setting
        // if set to "emulator" then run on emulator, otherwise on the configuration
        // provided in GoogleService-Info.plist
        let firebaseProject = Bundle.main.object(forInfoDictionaryKey: "FirebaseProject") as! String
        if firebaseProject == "emulator" {
            Logger.firebase.debug("Using firebase emulator")
            let options = FirebaseOptions(
                googleAppID: "1:1015622064814:ios:de6eac6d62f0f087b7eb3f",
                gcmSenderID: "1015622064814"
            )
            options.clientID = "1015622064814-folagjdh01kajtaset6van9euommo3pk.apps.googleusercontent.com"
            options.apiKey = "AIzaSyABylJo9Mn-jah1wTS6MEZfPNsMkH9QG5Q"
            options.projectID = "development-18fcf"
            options.storageBucket = "development-18fcf.appspot.com"
            FirebaseApp.configure(options: options)
            Auth.auth().useEmulator(withHost: "localhost", port: 9099)
            Storage.storage().useEmulator(withHost: "localhost", port: 9199)
            let settings = Firestore.firestore().settings
            settings.host = "localhost:9001"
            settings.isPersistenceEnabled = false
            settings.isSSLEnabled = false
            Firestore.firestore().settings = settings
        } else {
            Logger.firebase.debug("Using firebase project: \(FirebaseOptions.defaultOptions()?.projectID ?? "?")")
            FirebaseApp.configure()
            // ACHTUNG: isPersistenceEnabled must be true for Firestore. Otherwise it won't notify about
            // removed objects while the app was not running
        }
    }

    // MARK: UISceneSession Lifecycle

    func application(
        _: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options _: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
    }
}
