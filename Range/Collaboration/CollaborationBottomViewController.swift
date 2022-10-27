import Foundation
import UIKit

/// View controller showing the collaboration CTAs at the bottom of the screen (shown when CTAs in the collaboration view scroll to the
/// top so they're not visible)
class CollaborationBottomViewController: UIViewController, NonModalCardCoordinating {
    var cardDragging: NonModalCardDragging?

    enum Constants {
        static let verticalPadding = 16.0
        static let ctasHeight = 40.0
    }

    var ctas: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .dynamicColor(light: .Neutral_01, dark: .Neutral_10)

        updateShadow()

        let topStroke = UIView()
        topStroke.backgroundColor = .dynamicColor(
            light: .Neutral_01, // in light mode the same color as background as we don't want the stroke
            dark: .Neutral_07
        )
        view.addSubview(topStroke)
        topStroke.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.height.equalTo(1)
        }

        ctas = _createCollaborationCTAs()
        view.addSubview(ctas)
        ctas.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Constants.verticalPadding)
            make.leading.trailing.equalToSuperview().inset(16).priority(.high)
            make.height.equalTo(Constants.ctasHeight)
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateShadow()
        }
    }

    private func updateShadow() {
        let darkMode = traitCollection.userInterfaceStyle == .dark
        if darkMode {
            view.setShadowWithFigmaValues(x: 0, y: -6, blur: 10, opacity: 0.1)
        } else {
            view.setShadowWithFigmaValues(x: 0, y: -3, blur: 6, opacity: 0.1)
        }
    }
}

// MARK: - card presentable

extension CollaborationBottomViewController: CardPresentable {
    func height(forContainer _: UIView, cardPosition: CardPosition) -> CGFloat {
        if cardPosition == .min {
            return 0
        } else if cardPosition == .medium {
            return -1 // not supported
        }
        return Constants.verticalPadding + Constants.ctasHeight + Constants.verticalPadding
    }
}
