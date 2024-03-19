import Combine
import Foundation
import Knock
import OSLog
import UIKit

/// For presenting InAppFeedTableViewController in a card
class InAppFeedCardViewController: SheetCardViewController {
    private let feedTableVC: InAppFeedTableViewController

    private var markAllAsReadButton: RangeButton!

    private var subscriptions = Set<AnyCancellable>()

    init(model: KnockFeedModel, variant: InAppFeedItemTableViewCell.Variant) {
        feedTableVC = InAppFeedTableViewController(model: model, variant: variant)
        super.init(
            icon: UIImage(systemName: "bell"),
            title: String(localized: "Notifications")
        )

        feedTableVC.onItemSelected = { [weak self] _ in
            self?.dismissCard()
        }

        model.$feed
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                // mark all seen if the feed updates while user is looking at it
                self.updateMarkAllAsReadButtonEnabled()
            }
            .store(in: &subscriptions)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        add(childController: feedTableVC, toView: containerView)

        setupMarkAllAsReadButton()
        setupViewModeToggle()

        addSheetHeaderStroke()
        addSheetHeaderShadowBasedOnDrivingScrollView()

        containerView.insertSubview(feedTableVC.view, belowSubview: sheetHeaderView)
        feedTableVC.view.snp.makeConstraints { make in
            make.top.equalTo(sheetHeaderView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }

        updateMarkAllAsReadButtonEnabled()
    }

    override func height(forContainer cardContainerView: UIView, cardPosition: CardPosition) -> CGFloat {
        if cardPosition == .max {
            // just make it max, so it doesn't depend on the content height
            return Double.greatestFiniteMagnitude
        } else {
            return super.height(forContainer: cardContainerView, cardPosition: cardPosition)
        }
    }

    override func drivingScrollView() -> UIScrollView? {
        feedTableVC.tableView
    }

    private func setupMarkAllAsReadButton() {
        guard markAllAsReadButton == nil else { return }
        var config = UIButton.Configuration.filled()
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10)
        config.baseBackgroundColor = .dynamic(.Neutral_09)
        config.baseForegroundColor = .dynamic(.Neutral_04)
        config.cornerStyle = .fixed
        config.background.cornerRadius = 15
        config.background.strokeColor = .dynamic(.Neutral_07)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.preferredFont(forTextStyle: .footnote)
            return outgoing
        }
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .caption2)
        config.imagePlacement = .trailing
        config.imagePadding = 4
        markAllAsReadButton = RangeButton(
            configuration: config,
            primaryAction: UIAction(
                title: String(localized: "Mark all as read"),
                image: UIImage(systemName: "checkmark.circle")
            ) { [weak self] _ in
                self?.feedTableVC.markAllRead()
            }
        )
        .withCustomRangeHighlightColor()

        // more vertical tap area as button is only 30 points high
        markAllAsReadButton.tapAreaInsets = UIEdgeInsets(top: -10, left: 0, bottom: -10, right: 0)

        sheetHeaderView.addSubview(markAllAsReadButton)
        markAllAsReadButton.snp.makeConstraints { make in
            make.centerY.equalTo(closeButton)
            make.trailing.equalTo(closeButton.snp.leading).offset(-8)
            make.height.equalTo(30)
        }
    }

    private func setupViewModeToggle() {
        addSheetHeaderSubview(feedTableVC.viewModeToggle)
        feedTableVC.viewModeToggle.snp.makeConstraints { make in
            make.height.equalTo(SegmentedControl.height)
        }
    }

    private func updateMarkAllAsReadButtonEnabled() {
        guard markAllAsReadButton != nil else { return }
        markAllAsReadButton.isEnabled = feedTableVC.model.feed.meta.unread_count > 0
    }
}
