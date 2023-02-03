import Foundation
import RealmSwift
import UIKit

/// Button displaying the status name and a chevron.down icon with a background in status color.
class CollaborationStatusButton: ButtonWithTapAreaInsets {
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
        setTitle(collaboration.status?.name ?? "", for: .normal)
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

        // more vertical tap area as button is only 32 points high
        configurationUpdateHandler = { [weak self] button in
            guard let self = self else { return }
            guard !self.collaboration.isInvalidated else { return }
            var config = button.configuration
            config?.baseBackgroundColor = self.collaboration.status?.color ?? .Primary_Blue_04
            button.configuration = config
        }
        configuration = config
        setImage(UIImage(systemName: "chevron.down"), for: .normal)
    }

    deinit {
        collaborationNotificationToken?.invalidate()
    }
}
