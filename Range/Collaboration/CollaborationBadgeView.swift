import Foundation
import RealmSwift
import UIKit

/// Badge for a collaboration that display uploads count and a flag.
/// It observes the collaboration and reloads if it's updated.
class CollaborationBadgeView: ViewWithTapAreaInsets {
    private let collaboration: Collaboration
    private var collaborationNotificationToken: NotificationToken?
    private var geometryNotificationToken: NotificationToken?
    private var commentsNotificationToken: NotificationToken?
    // the pink circle
    private var badgeView = UIView()
    // optional label showing number of uploads, only for photo collabs (= no status)
    private var numberOfUploadsLabel: UILabel?
    // optional checkmark shown for collaborations having status (instead of the numberOfUploadsLabel)
    private var checkmarkView: UIImageView?
    // optional marker view showing a flag if there are any uncompleted comments or an overdue icon
    private var markerView: UIImageView?

    init(_ collaboration: Collaboration) {
        self.collaboration = collaboration
        super.init(frame: .zero)

        // make the tappable area bigger as this view intrinsic size is 32/32i
        tapAreaInsets = UIEdgeInsets(top: -4, left: -4, bottom: -4, right: -4)
        setContentHuggingPriority(.required, for: .horizontal)

        setupView()

        collaborationNotificationToken = collaboration.observe { [weak self] _ in
            self?.updateBadge()
        }
        geometryNotificationToken = collaboration.feature.first?.geometry.first?.observe { [weak self] _ in
            self?.updateBadge()
        }
        // observe comments as the badge depends on whether there are any uncompleted comments
        commentsNotificationToken = collaboration.comments.observe { [weak self] _ in
            self?.updateBadge()
        }
        updateBadge()
    }

    deinit {
        collaborationNotificationToken?.invalidate()
        geometryNotificationToken?.invalidate()
        commentsNotificationToken?.invalidate()
    }

    private func setupView() {
        backgroundColor = .clear

        badgeView.layer.cornerRadius = 16
        badgeView.layer.borderWidth = 1
        badgeView.layer.borderColor = UIColor(white: 0, alpha: 0.2).cgColor
        addSubview(badgeView)
        badgeView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    /// Updates the number on the badge and shows/hides the flag
    private func updateBadge() {
        let uploadsCount = collaboration.uploads.count

        if let status = collaboration.status {
            // display status
            badgeView.backgroundColor = collaboration.isArchived ? .Neutral_05 : status.color
            numberOfUploadsLabel?.isHidden = true
            if let checkmarkView = checkmarkView {
                checkmarkView.isHidden = false
            } else {
                setupCheckmarkView()
            }
        } else {
            // display number of photos
            badgeView.backgroundColor = collaboration.isArchived ? .Neutral_05 : .Pink_03
            if let label = numberOfUploadsLabel {
                label.isHidden = false
            } else {
                setupNumberOfUploadsLabel()
            }
            numberOfUploadsLabel?.text = uploadsCount < 9 ? String(uploadsCount) : "9⁺"
            checkmarkView?.isHidden = true
        }

        if !collaboration.isArchived, collaboration.isOverdue || collaboration.hasUncompletedNotes {
            if let markerView = markerView {
                markerView.isHidden = false
            } else {
                setupMarkerView()
            }
            // overdue mark is higher priority than uncompleted notes
            markerView?.image = UIImage(named: collaboration.isOverdue ? "badge.overdue" : "badge.note")
        } else {
            markerView?.isHidden = true
        }
    }

    /// Creates the note flag image view
    private func setupMarkerView() {
        let marker = UIImageView(image: UIImage(named: "badge.note"))
        addSubview(marker)
        marker.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(22)
            make.bottom.equalToSuperview().offset(-23)
        }
        marker.setShadowWithFigmaValues(y: 4.62, blur: 7.69, opacity: 0.2)

        markerView = marker
    }

    /// Create a label to display number of photos
    private func setupNumberOfUploadsLabel() {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .bold)
        label.textColor = .Neutral_01
        addSubview(label)
        label.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        numberOfUploadsLabel = label
    }

    /// Setup image view showing checkmark for collaborations with status
    private func setupCheckmarkView() {
        let imageConfig = UIImage.SymbolConfiguration(weight: .bold)
        let checkmark = UIImageView(image: UIImage(systemName: "checkmark", withConfiguration: imageConfig))
        checkmark.tintColor = .Neutral_01
        addSubview(checkmark)
        checkmark.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        checkmarkView = checkmark
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: 32, height: 32)
    }
}
