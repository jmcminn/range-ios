import Combine
import Foundation
import Knock
import OSLog
import UIKit

/// For presenting InAppFeedTableViewController in a view controller with a navigation bar to be presented for an organization
class OrganizationInAppFeedViewController: UIViewController {
    /// Model to access the current organization and projects
    let model: OrganizationModel
    let userDataSyncState: UserDataSyncState

    private let feedTableVC: InAppFeedTableViewController

    var onOrganizationButtonTap: (() -> Void)?

    private let titleLabel = UILabel()
    private let headerStroke = UIView()
    private var markAllAsReadButton: RangeButton!
    private let dataSyncIndicatorView: DataSyncIndicatorView
    private let billingErrorIndicatorView: BillingErrorIndicatorView

    private var subscriptions = Set<AnyCancellable>()

    init(model: OrganizationModel, userDataSyncState: UserDataSyncState) {
        self.model = model
        self.userDataSyncState = userDataSyncState
        feedTableVC = InAppFeedTableViewController(
            model: model.knockFeedModel,
            variant: .organization,
            participantProvider: { userId in model.mainRealm.object(ofType: Participant.self, forPrimaryKey: userId) }
        )
        self.dataSyncIndicatorView = DataSyncIndicatorView(userDataSyncState)
        self.billingErrorIndicatorView = BillingErrorIndicatorView(model.organization)
        super.init(nibName: nil, bundle: nil)

        model.knockFeedModel.$feed
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // mark all seen if the feed updates while user is looking at it
                self?.updateMarkAllAsReadButtonEnabled()
            }
            .store(in: &subscriptions)
        
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTitleLabel()
        setupOrganizationSelectorButton()
        setupMarkAllAsReadButton()
        setupDataSyncIndicatorView()
        setupBillingErrorIndicatorView()

        view.backgroundColor = .dynamic(.Neutral_10)

        add(childController: feedTableVC, toView: view)

        setupViewModeToggle()
        setupHeaderStroke()

        feedTableVC.view.snp.makeConstraints { make in
            make.top.equalTo(headerStroke.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }

        updateMarkAllAsReadButtonEnabled()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    private func setupTitleLabel() {
        titleLabel.text = String(localized: "Notifications")
        titleLabel.textColor = .dynamic(.Neutral_04)
        titleLabel.font = UIFont._preferredFont(forTextStyle: .body, symbolicTraits: .traitBold)
        titleLabel.adjustsFontForContentSizeCategory = true
        view.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(self.view.safeAreaLayoutGuide.snp.top).offset(6)
            make.centerX.equalToSuperview()
        }
    }

    private func setupViewModeToggle() {
        view.addSubview(feedTableVC.viewModeToggle)
        feedTableVC.viewModeToggle.snp.makeConstraints { make in
            make.height.equalTo(SegmentedControl.height)
            make.top.equalTo(titleLabel.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
        }
    }

    private func setupHeaderStroke() {
        headerStroke.backgroundColor = .dynamic(.Neutral_07)
        view.addSubview(headerStroke)
        headerStroke.snp.makeConstraints { make in
            make.top.equalTo(feedTableVC.viewModeToggle.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(1)
        }
    }

    private func updateMarkAllAsReadButtonEnabled() {
        guard markAllAsReadButton != nil else { return }
        markAllAsReadButton.isEnabled = model.knockFeedModel.feed.meta.unread_count > 0
    }

    private func setupOrganizationSelectorButton() {
        let button = RangeButton(
            configuration: .organizationSelector(model.organization),
            primaryAction: UIAction { [weak self] _ in
                self?.onOrganizationButtonTap?()
            }
        )
        .withCustomRangeHighlightColor()

        button.tapAreaInsets = UIEdgeInsets(top: -4, left: -4, bottom: -4, right: -4)

        view.addSubview(button)
        button.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.width.height.equalTo(32)
            make.centerY.equalTo(titleLabel)
        }
    }

    private func setupMarkAllAsReadButton() {
        guard markAllAsReadButton == nil else { return }

        var config = UIButton.Configuration.filled()
        config.baseForegroundColor = .dynamic(.Neutral_04)
        config.baseBackgroundColor = .clear
        markAllAsReadButton = RangeButton(
            configuration: config,
            primaryAction: UIAction(image: UIImage(
                systemName: "checkmark.circle",
                withConfiguration: UIImage.SymbolConfiguration(font: .preferredFont(forTextStyle: .headline))
            )) { [weak self] _ in
                self?.feedTableVC.markAllRead()
            }
        )
        markAllAsReadButton.tapAreaInsets = UIEdgeInsets(top: -10, left: -10, bottom: -10, right: -10)
        view.addSubview(markAllAsReadButton)
        markAllAsReadButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(8)
            make.centerY.equalTo(titleLabel)
        }
    }

    private func setupDataSyncIndicatorView() {
        dataSyncIndicatorView.onTapped = { [weak self] in
            guard let self else { return }
            _dataSyncInfoCard(userDataSyncState.state).installAndShowCard(in: self._rootViewController())
        }
        view.addSubview(dataSyncIndicatorView)
        dataSyncIndicatorView.snp.makeConstraints { make in
            make.trailing.equalTo(markAllAsReadButton.snp.leading).offset(2)
            make.centerY.equalTo(markAllAsReadButton)
        }
    }
    
    private func setupBillingErrorIndicatorView() {
        billingErrorIndicatorView.onTapped = { [weak self] in
            guard let self else { return }
            OrganizationBillingErrorCardViewController(model).installAndShowCard(in: self._rootViewController())
        }
        view.addSubview(billingErrorIndicatorView)
        billingErrorIndicatorView.snp.makeConstraints { make in
            make.trailing.equalTo(dataSyncIndicatorView.snp.leading).offset(2)
            make.centerY.equalTo(markAllAsReadButton)
        }
    }
}
