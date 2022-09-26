import Foundation
import RealmSwift
import UIKit

/// Badge for a collaboration that display uploads count and a flag.
/// It observes the collaboration and reloads if it's updated.
class CollaborationBadgeView: UIView {
    private let collaboration: Collaboration
    private var collaborationNotificationToken: NotificationToken?
    // the pink circle
    private var badgeView = UIView()
    // label showing number of upload
    private var label = UILabel()
    // optional note view showing a flag if there are any uncompleted comments
    private var noteView: UIImageView?

    init(_ collaboration: Collaboration) {
        self.collaboration = collaboration
        super.init(frame: .zero)

        setContentHuggingPriority(.required, for: .horizontal)

        setupView()

        collaborationNotificationToken = collaboration.observe { [weak self] _ in
            self?.updateBadge()
        }
        updateBadge()
    }

    deinit {
        collaborationNotificationToken?.invalidate()
    }

    private func setupView() {
        backgroundColor = .clear

        badgeView.layer.cornerRadius = 16
        badgeView.layer.borderWidth = 1
        badgeView.layer.borderColor = UIColor.Pink_04.cgColor
        badgeView.backgroundColor = .Pink_03
        addSubview(badgeView)
        badgeView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        label.font = .systemFont(ofSize: 17, weight: .bold)
        label.textColor = .Neutral_01
        addSubview(label)
        label.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }

    /// Updates the number on the badge and shows/hides the flag
    private func updateBadge() {
        let uploadsCount = collaboration.uploads.count
        label.text = uploadsCount < 9 ? String(uploadsCount) : "9⁺"

        if collaboration.hasUncompletedNotes {
            if let noteView = noteView {
                noteView.isHidden = false
            } else {
                setupNoteView()
            }
        } else {
            noteView?.isHidden = true
        }
    }

    /// Creates the note flag image view
    private func setupNoteView() {
        let noteView = UIImageView(image: UIImage(named: "badge.note"))
        addSubview(noteView)
        noteView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(18)
            make.bottom.equalToSuperview().offset(-19)
        }
        noteView.setShadowWithFigmaValues(y: 4.62, blur: 7.69, opacity: 0.2)

        self.noteView = noteView
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: 32, height: 32)
    }
}
