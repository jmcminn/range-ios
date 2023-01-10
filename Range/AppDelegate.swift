import Firebase
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import FirebaseStorage
import OSLog
import Sentry
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        setupAppearance()

        initiateSentry()

        initiateFirebase()

        return true
    }

    /// Set appearance for UI elements
    private func setupAppearance() {
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()
        tabBarAppearance.backgroundColor = .dynamicColor(light: .Neutral_01, dark: .Neutral_10)
        tabBarAppearance.stackedLayoutAppearance.normal.iconColor = .dynamicColor(light: .Neutral_07, dark: .Neutral_04)
        tabBarAppearance.stackedLayoutAppearance.normal
            .titleTextAttributes = [.foregroundColor: UIColor.dynamicColor(light: .Neutral_07, dark: .Neutral_04)]
        UITabBar.appearance().standardAppearance = tabBarAppearance
//        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        UITabBar.appearance().tintColor = .Primary_Blue_04
    }

    private func initiateSentry() {
        guard let sentryEnv: String = try? AppConfiguration.value(for: "SentryEnv"), sentryEnv.isEmpty == false else {
            Logger.sentry.debug("No sentry environment provided! Not starting sentry")
            return
        }
        Logger.sentry.debug("Starting sentry for '\(sentryEnv)' environment")

        SentrySDK.start { options in
            options.dsn = "https://5c3c709066fb4b5e897f79841727332a@o1384740.ingest.sentry.io/4504475534032896"
            // for debugging
//            options.debug = true // Enabled debug when first installing is always helpful
//            options.diagnosticLevel = .warning
            options.environment = sentryEnv
        }
    }

    private func initiateFirebase() {
        // firebase emulator enabled in the "Debug firebase emulator" configuration
        // in the `FIREBASE_PROJECT` custom build setting
        // if set to "emulator" then run on emulator, otherwise on the configuration
        // provided in GoogleService-Info.plist
        let firebaseProject: String = try! AppConfiguration.value(for: "FirebaseProject")
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
