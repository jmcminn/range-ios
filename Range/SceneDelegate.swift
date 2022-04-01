import CoreLocation
import PDFKit
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let windowScene = (scene as? UIWindowScene) else { return }
        window = UIWindow(windowScene: windowScene)
        
        guard let documentUrl = Bundle.main.url(forResource: "5451 VANDERBILT AVE-A1.1A", withExtension: "pdf") else { return }
        guard let document = PDFDocument(url: documentUrl) else { return }
        guard let pdfPage = document.page(at: 0) else { return }
        
        // center on the initial position used in the web app https://gitlab.com/range.io/range.io/-/blob/1e0485d391a4c7f8c7ee283a9e01aca585bcc7d3/modules/range-editor/src/redux/slices/geometry-slice.js#L40
        let pdfSource = PDFSource(
            center: CLLocationCoordinate2D(latitude: 32.82478, longitude: -96.77528),
            page: pdfPage,
            scale: 1/48.0
        )
        
        let projectFC = ProjectFlowController(pdfSource: pdfSource)
        window!.rootViewController = projectFC
        window!.makeKeyAndVisible()
        
        projectFC.start()
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }
    
    
}

