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
        vc.modalPresentationStyle = .custom
        vc.transitioningDelegate = self
        self.present(vc, animated: true)
    }
    
}

extension ProjectFlowController: UIViewControllerTransitioningDelegate {
    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        return CardPresentationController(presentedViewController: presented as! CardPresentable, presenting: presenting)
    }
}
