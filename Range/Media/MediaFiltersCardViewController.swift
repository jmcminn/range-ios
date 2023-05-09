import Combine
import Foundation
import RealmSwift
import UIKit

/// Card view controller presenting filters for media view (for filtering Uploads)
/// It presents the overlay over the presenting view controller.
/// It can be dismissed by tapping the overlay, dragging down or tappin on the close button.
class MediaFiltersCardViewController: SheetCardViewController {
    unowned let model: ProjectModel
    private let mediaFilters: MediaFilters
    private let usersViewModel: UsersViewModel
    private let tagsViewModel: TagsViewModel

    private var resetButton: ButtonWithTapAreaInsets!

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    private let filterByAuthorSwitch = UISwitch()
    private let usersView: SelectedUsersView
    private let filterByTagsSwitch = UISwitch()
    private let tagsView: SelectedTagsView

    private var gradientViews = [GradientView]()

    /// Initializer
    ///
    /// - Parameters:
    ///     - mediaFilters:                         MediaFilters
    init(model: ProjectModel, mediaFilters: MediaFilters) {
        self.model = model
        self.mediaFilters = mediaFilters

        let usersViewModel = UsersViewModel(model: model, multiselect: true)
        // preselect users from filters
        mediaFilters.authorFilter?.forEach { usersViewModel.set(userWithId: $0, selected: true) }
        usersView = SelectedUsersView(viewModel: usersViewModel, showEditUserCell: true)
        self.usersViewModel = usersViewModel

        let tagsViewModel = TagsViewModel(model: model, untaggedTagName: String(localized: "Untagged Media"))
        // preselect tags from the filter
        mediaFilters.tagsFilter?.forEach { tagsViewModel.set(tagWithId: $0, selected: true) }
        tagsView = SelectedTagsView(viewModel: tagsViewModel, showEditTagCell: true)
        self.tagsViewModel = tagsViewModel

        super.init(
            icon: UIImage(named: "filter.search"),
            title: String(localized: "Media Filters"),
            subtitle: "pins on canvas"
        )

        usersViewModel.addDelegate(self)
        tagsViewModel.addDelegate(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        addSheetHeaderStroke()
        addSheetHeaderShadowBasedOnDrivingScrollView()

        setupResetButton()

        setupViews()

        filterByAuthorSwitch.addAction(.init(handler: { [weak self] _ in
            self?.onFilterByAuthorSwitchAction()
        }), for: .valueChanged)

        filterByTagsSwitch.addAction(.init(handler: { [weak self] _ in
            self?.onFilterByTagsSwitchAction()
        }), for: .valueChanged)

        updateControlsStateFromFilters()

        updateColors()
    }

    private func updateControlsStateFromFilters() {
        filterByAuthorSwitch.setOn(mediaFilters.authorFilter != nil, animated: false)
        filterByTagsSwitch.setOn(mediaFilters.tagsFilter != nil, animated: false)
        usersView.setVisible(mediaFilters.authorFilter != nil, animated: false)
        tagsView.setVisible(mediaFilters.tagsFilter != nil, animated: false)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(
            self, selector: #selector(mediaFiltersUpdated),
            name: MediaFilters.UpdateNotificationName, object: nil
        )
        mediaFiltersUpdated()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }

    @objc func mediaFiltersUpdated() {
        resetButton.isHidden = mediaFilters.hasDefaultValues

        let uploadsCount = model.mainRealm.objects(Upload.self)
            .where { $0.placeholder == false }
            .filter(mediaFilters.match)
            .count
        subtitleLabel?.text = uploadsCount == 1
            ? String(localized: "1 media item showing")
            : String(localized: "\(uploadsCount) media items showing")
    }

    private func setupViews() {
        // Scroll view setup
        scrollView.alwaysBounceVertical = true
        containerView.insertSubview(scrollView, belowSubview: sheetHeaderView)
        scrollView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(sheetHeaderView.snp.bottom)
            make.bottom.equalToSuperview().inset(12)
        }

        // Stack view setup
        stackView.axis = .vertical
        stackView.layer.cornerRadius = 13
        stackView.layer.borderWidth = 1
        stackView.backgroundColor = .dynamic(.Neutral_09)
        scrollView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.top.bottom.leading.trailing.equalToSuperview().inset(16)
        }

        // ----- Author --------------------------------------------------------------------------
        add(label: createLabel(text: String(localized: "Filter by Users")), control: filterByAuthorSwitch,
            bottomInset: 4) // the rest = 9 is added below users view
        addUsersView()
        addSpace(height: 9)
        addSeparator()

        // ----- Tags ------------------------------------------------------------------------------
        add(label: createLabel(text: String(localized: "Filter by Tags")), control: filterByTagsSwitch,
            bottomInset: 4) // the rest = 9 is added below tags view
        addTagsView()
        addSpace(height: 9)
        addSeparator()
    }

    /// Adds given label and control to the stack view with proper insets
    private func add(label: UILabel, control: UIView, topInset: Double = 13, bottomInset: Double = 13) {
        // wrapper to add leading/trailing insets
        let wrapper = UIView()
        let labelAndControl = UIStackView()
        labelAndControl.axis = .horizontal
        labelAndControl.alignment = .center
        labelAndControl.addArrangedSubview(label)
        labelAndControl.addArrangedSubview(control)
        wrapper.addSubview(labelAndControl)
        stackView.addArrangedSubview(wrapper)
        labelAndControl.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(topInset)
            make.bottom.equalToSuperview().inset(bottomInset)
            make.leading.trailing.equalToSuperview().inset(16)
            make.width.equalTo(scrollView).offset(-64)
        }
    }

    /// add some empty space
    private func addSpace(height: Double) {
        let space = UIView()
        space.backgroundColor = stackView.backgroundColor
        stackView.addArrangedSubview(space)
        space.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(height)
        }
    }

    /// leftInset insets the line from the left (makes it shorter)
    private func addSeparator(leftInset: Double = 0.0) {
        let separator = UIView()
        separator.backgroundColor = .dynamic(.Neutral_07)
        stackView.addArrangedSubview(separator)
        separator.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(leftInset)
            make.height.equalTo(1)
        }
    }

    private func addUsersView() {
        usersView.backgroundColor = stackView.backgroundColor
        stackView.addArrangedSubview(usersView)
        usersView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(40)
        }
        usersView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(usersTapped)))

        addLeftRightGradients(to: usersView)
    }

    private func addTagsView() {
        tagsView.backgroundColor = stackView.backgroundColor
        stackView.addArrangedSubview(tagsView)
        tagsView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(40)
        }
        tagsView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tagsTapped)))

        addLeftRightGradients(to: tagsView)
    }

    private func addLeftRightGradients(to superView: UIView) {
        let leftGradientView = createLeftGradient()
        let rightGradientView = createRightGradient()
        superView.addSubview(leftGradientView)
        superView.addSubview(rightGradientView)
        leftGradientView.snp.makeConstraints { make in
            make.width.equalTo(24)
            make.top.bottom.left.equalToSuperview()
        }
        rightGradientView.snp.makeConstraints { make in
            make.width.equalTo(24)
            make.top.bottom.right.equalToSuperview()
        }
        gradientViews.append(leftGradientView)
        gradientViews.append(rightGradientView)
    }

    private func createLeftGradient() -> GradientView {
        let leftGradientView = GradientView()
        leftGradientView.backgroundColor = .clear
        // left to right gradient
        leftGradientView.gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        leftGradientView.gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        return leftGradientView
    }

    private func createRightGradient() -> GradientView {
        let rightGradientView = GradientView()
        rightGradientView.backgroundColor = .clear
        // right to left gradient
        rightGradientView.gradientLayer.startPoint = CGPoint(x: 1, y: 0.5)
        rightGradientView.gradientLayer.endPoint = CGPoint(x: 0, y: 0.5)
        return rightGradientView
    }

    private func createLabel(text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = .dynamic(.Neutral_04)
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        return label
    }

    private func setupResetButton() {
        guard resetButton == nil else { return }
        var config = UIButton.Configuration.filled()
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10)
        config.baseBackgroundColor = .Green_01
        config.baseForegroundColor = .dynamic(.Neutral_04)
        config.cornerStyle = .fixed
        config.background.cornerRadius = 15
        config.background.strokeColor = .systemGreen
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.preferredFont(forTextStyle: .subheadline)
            return outgoing
        }
        resetButton = ButtonWithTapAreaInsets(
            configuration: config,
            primaryAction: UIAction(title: String(localized: "Reset")) { [weak self] _ in
                self?.mediaFilters.resetToDefaults()
                self?.updateControlsStateFromFilters()
            }
        )
        // more vertical tap area as button is only 30 points high
        resetButton.tapAreaInsets = UIEdgeInsets(top: -10, left: 0, bottom: -10, right: 0)

        sheetHeaderView.addSubview(resetButton)
        resetButton.snp.makeConstraints { make in
            make.centerY.equalTo(closeButton)
            make.trailing.equalTo(closeButton.snp.leading).offset(-8)
            make.height.equalTo(30)
        }
    }

    override func updateColors() {
        super.updateColors()
        stackView.layer.borderColor = chooseColor(.Neutral_07).cgColor
        let gradientColor = chooseColor(.Neutral_09)
        gradientViews.forEach {
            $0.gradientLayer.colors = [
                gradientColor.cgColor,
                gradientColor.withAlphaComponent(0).cgColor,
            ]
        }
    }

    override func height(forContainer cardContainerView: UIView, cardPosition: CardPosition) -> CGFloat {
        let baseHeight = super.height(forContainer: cardContainerView, cardPosition: cardPosition)

        if cardPosition == .max {
            view.layoutIfNeeded()
            return baseHeight + scrollView.contentSize.height + 12.0
        }
        return baseHeight
    }

    override func drivingScrollView() -> UIScrollView? {
        scrollView
    }
}

// MARK: - author

extension MediaFiltersCardViewController: UsersViewModelDelegate {
    /// Called when "Filter by Users" switch is toggled
    private func onFilterByAuthorSwitchAction() {
        if filterByAuthorSwitch.isOn {
            mediaFilters.authorFilter = []
            usersView.setVisible(true)
            showUsersPicker()
        } else {
            usersViewModel.clearSelection()
            mediaFilters.authorFilter = nil
            usersView.setVisible(false)
        }
        if let cardDragging = cardDragging {
            cardDragging.setCardHeight(cardDragging.cardHeight(forPosition: cardDragging.position), animated: true)
        }
    }

    /// Invoked when selected users tapped
    @objc private func usersTapped() {
        showUsersPicker()
    }

    /// Show the picker that operates on usersViewModel
    func showUsersPicker() {
        guard let presentingVC = presentingVC else { return }
        UserPickerCardViewController(title: "Users", viewModel: usersViewModel)
            .installAndShowCard(in: presentingVC)
    }

    /// Updates author filters when the usersViewModel is updated
    func usersViewModel(
        _ viewModel: UsersViewModel,
        user _: UserViewModel,
        selected _: Bool,
        indexInSelectedUsers _: Int
    ) {
        mediaFilters.authorFilter = viewModel.selectedUsers.map(\.id)
    }
}

// MARK: - tags

extension MediaFiltersCardViewController: TagsViewModelDelegate {
    /// Called when "Filter by Tags" switch is toggled
    private func onFilterByTagsSwitchAction() {
        if filterByTagsSwitch.isOn {
            mediaFilters.tagsFilter = []
            tagsView.setVisible(true)
            showTagsSelector()
        } else {
            tagsViewModel.clearSelection()
            mediaFilters.tagsFilter = nil
            tagsView.setVisible(false)
        }
        if let cardDragging = cardDragging {
            cardDragging.setCardHeight(cardDragging.cardHeight(forPosition: cardDragging.position), animated: true)
        }
    }

    /// Invoked when selected tags are tapped
    @objc private func tagsTapped() {
        showTagsSelector()
    }

    /// Show Tags selection card operating on the tagsViewModel used by this card (so all changes are propagated to this view automatically)
    private func showTagsSelector() {
        guard let presentingVC = presentingVC else { return }
        let editTagsVC = SearchAndSelectTagsViewController(tagsViewModel: tagsViewModel)
        editTagsVC.showCreateTag = false
        editTagsVC.showUntaggedOption = true
        editTagsVC.showTagCount = false
        editTagsVC.installAndShowCard(in: presentingVC, inView: view.superview)
    }

    /// Updates tags filters when the tagsViewModel is updated
    func tagsViewModel(_ viewModel: TagsViewModel, tag _: TagViewModel, selected _: Bool, indexInSelectedTags _: Int) {
        mediaFilters.tagsFilter = viewModel.selectedTags.map(\.id)
    }
}
