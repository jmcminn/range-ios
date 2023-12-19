import Foundation
import SwiftUI
import UIKit

/// Controls the "create project" wizard
class CreateProjectFlowController: UINavigationController {
    let viewModel = CreateProjectViewModel()
    var onCancelled: (() -> Void)?

    init() {
        super.init(rootViewController: UIViewController())
        isNavigationBarHidden = true
        showStep1View()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func showStep1View() {
        let view = CreateProjectStep1View(
            model: viewModel,
            onMapTap: { [weak self] coordinate in
                /// Mapbox  MapViewAnnotation was not always responding to location changes without resetting to nil... (???)
                self?.viewModel.location = nil
                DispatchQueue.main.async {
                    self?.viewModel.location = coordinate
                }
            },
            cancelAction: { [weak self] in self?.onCancelled?() },
            nextAction: {}
        )
        setViewControllers([UIHostingController(rootView: view)], animated: false)
    }
}
