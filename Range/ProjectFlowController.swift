import UIKit

/// Main view controller for displaying a project.
/// It manages the UI state of project and all view transitions.
final class ProjectFlowController: UIViewController {
    
    let pdfSource: PDFSource
    
    init(pdfSource: PDFSource) {
        self.pdfSource = pdfSource
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func start() {
        showSource()
    }
    
    fileprivate func showSource() {
        let sourceVC = AnnotatedPDFViewController(pdfSource: pdfSource)
        add(childController: sourceVC)
        
        showActionCard()
    }
    
    fileprivate func showActionCard() {
        let vc = ProjectActionCardViewController()
        vc.installCardDisplayController(cardConfig: CardConfiguration(showSafeAreaBlur: true))
        self.present(vc, animated: true)
    }
}
