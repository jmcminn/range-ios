import Foundation
import RealmSwift
import UIKit

/// Button displaying the status name and a chevron.down icon with a background in status color.
class CollaborationStatusButton: RangeButton {
    private let collaboration: Collaboration
    private var collaborationNotificationToken: NotificationToken?

    init(_ collaboration: Collaboration) {
        self.collaboration = collaboration
        super.init(frame: .zero)

        tapAreaInsets = UIEdgeInsets(top: -4, left: 0, bottom: -4, right: 0)
        setupConfiguration()
        collaborationNotificationToken = collaboration.observe { [weak self] _ in
            self?.updateButton()
        }
        updateButton()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateButton() {
        guard !collaboration.isInvalidated else { return }
        if let status = collaboration.status, status.isInvalidated { return }
        setTitle(collaboration.status?.name ?? "", for: .normal)
        configuration?.baseBackgroundColor = collaboration.status?.color ?? .Primary_Blue_04
        setNeedsUpdateConfiguration()
    }

    private func setupConfiguration() {
        var config = UIButton.Configuration.filled()
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 8)
        config.baseForegroundColor = .Neutral_01
        config.cornerStyle = .fixed
        config.background.cornerRadius = 16
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont._preferredFont(forTextStyle: .subheadline, symbolicTraits: .traitBold)
            return outgoing
        }
        let imageConfig = UIImage.SymbolConfiguration(textStyle: .footnote)
        config.preferredSymbolConfigurationForImage = imageConfig
        config.imagePlacement = .trailing
        config.imagePadding = 6

        configuration = config
        setImage(UIImage(systemName: "chevron.down"), for: .normal)
    }

    deinit {
        collaborationNotificationToken?.invalidate()
    }
}
