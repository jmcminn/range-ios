
import Foundation
import SwiftUI
import UIKit

class AnnotationsToolbarViewController: UIHostingController<AnnotationsToolbarView> {
    init(viewModel: AnnotationsViewModel) {
        super.init(rootView: AnnotationsToolbarView(model: viewModel))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }
}
