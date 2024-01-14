import Foundation
import SnapKit
import UIKit

/// Card view controller presenting content from ItemPickerViewModel and allowing for selection.
/// It presents the overlay over the presenting view controller.
/// It can be dismissed by tapping the overlay, dragging down or tappin on the close button.
class ItemPickerCardViewController: SheetCardViewController {
    /// users to select
    private let viewModel: ItemPickerViewModel

    // background view for searchView that has the headerStroke at the bottom, added so it can
    // have a shadow when scrolling the list
    private let headerView = UIView()
    // only when viewModel is multiselect
    private let selectedView: SelectedItemPickerItemsView?
    private let headerStroke = UIView()
    private let tableView = UITableView(frame: .zero, style: .plain)

    private static var headerHeight = 0
    private static var headerHeightWithSelectedItems = 44
    private var headerHeightConstraint: Constraint?

    init(
        icon: UIImage?,
        title: String,
        searchPlaceholderText: String,
        viewModel: ItemPickerViewModel,
        selectedItemsViewConfig: SelectedItemPickerItemsView.Config
    ) {
        self.viewModel = viewModel
        selectedView = viewModel.multiselect
            ? SelectedItemPickerItemsView(viewModel: viewModel, config: selectedItemsViewConfig)
            : nil

        super.init(icon: icon, title: title, showSearchView: true)

        searchView.placeholderText = searchPlaceholderText
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHeaderVew()
        containerView.addSubview(headerView)
        headerView.snp.makeConstraints { make in
            make.top.equalTo(sheetHeaderView.snp.bottom)
            make.leading.trailing.equalToSuperview()
            if selectedView != nil, !viewModel.selectedItems.isEmpty {
                self.headerHeightConstraint = make.height
                    .equalTo(ItemPickerCardViewController.headerHeightWithSelectedItems).constraint
            } else {
                self.headerHeightConstraint = make.height.equalTo(ItemPickerCardViewController.headerHeight)
                    .constraint
            }
        }

        setupSearchView()

        if let selectedView = selectedView {
            selectedView.isHidden = viewModel.selectedItems.isEmpty
            headerView.addSubview(selectedView)
            selectedView.snp.makeConstraints { make in
                make.leading.trailing.bottom.equalToSuperview()
                make.bottom.equalToSuperview().offset(-12)
            }
        }

        setupHeaderStroke()
        headerView.addSubview(headerStroke)
        headerStroke.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(1)
        }

        setupTableView()
        containerView.insertSubview(tableView, belowSubview: headerView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(headerView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }

        viewModel.addDelegate(self)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // update the border color for cells
        tableView.reloadData()
        updateHeaderShadow()
    }

    override func height(forContainer cardContainerView: UIView, cardPosition: CardPosition) -> CGFloat {
        if cardPosition == .max {
            // just make it max, so it doesn't depend on the content height (because we want to
            // show the keyboard for searching anyway, so no point in changing the card position
            // back and forth when showing/hiding the keyboard)
            return Double.greatestFiniteMagnitude
        } else {
            return super.height(forContainer: cardContainerView, cardPosition: cardPosition)
        }
    }

    override func drivingScrollView() -> UIScrollView? {
        tableView
    }

    private func setupHeaderVew() {
        headerView.backgroundColor = .dynamic(.Neutral_10)
    }

    private func setupSearchView() {
        searchView.addDelegate(self)
    }

    private func setupHeaderStroke() {
        headerStroke.backgroundColor = .dynamic(.Neutral_07)
    }

    private func setupTableView() {
        tableView.backgroundColor = view.backgroundColor
        // distance between first section (the rest is covered by sections footers)
        tableView.tableHeaderView =
            UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 16))
        tableView.tableFooterView =
            UIView(frame: CGRect(x: 0, y: 0, width: 0, height: CGFloat.leastNormalMagnitude))
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.register(
            ItemPickerTableViewCell.self,
            forCellReuseIdentifier: ItemPickerTableViewCell.Variant.identifier(forMultiselect: viewModel.multiselect)
        )
        tableView.keyboardDismissMode = .onDrag
    }

    /// updates shadow color based on the interface style and visibility based on the `bottomStrokeVisible`
    private func updateHeaderShadow() {
        // the view to which the shadow is attached changes when showing selected items (because this view is not in sheetHeaderView)
        headerView.layer.shadowOpacity = 0
        sheetHeaderView.layer.shadowOpacity = 0

        let shadowVisible = tableView.contentOffset.y > 0
        if shadowVisible {
            let darkMode = traitCollection.userInterfaceStyle == .dark
            let viewWithShadow = (selectedView?.isHidden ?? true) ? sheetHeaderView : headerView
            if darkMode {
                viewWithShadow.setShadowWithFigmaValues(x: 0, y: 6, blur: 10, opacity: 0.1)
            } else {
                viewWithShadow.setShadowWithFigmaValues(x: 0, y: 3, blur: 6, opacity: 0.1)
            }
            // make the shadow height = 10 points, so the top part of the shadow is not visible
            // (the path covers bottom part of the view only)
            // This only works if the view is actually higher than 10 points. But if it's lower
            // then the shadow with no shadowPath would not be shown (for view that has 0 height)
            // so we still need to "cover" this view from top with another view (in a view that's
            // adding this view controller as a child)
            viewWithShadow.layer.shadowPath = UIBezierPath(rect: CGRect(x: 0,
                                                                        y: viewWithShadow.bounds.maxY - 10,
                                                                        width: viewWithShadow.bounds.width,
                                                                        height: 10)).cgPath
        }
    }

    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        super.scrollViewDidScroll(scrollView)
        updateHeaderShadow()
    }
}

// MARK: - view model delegate

extension ItemPickerCardViewController: ItemPickerViewModelDelegate {
    func itemPickerViewModel(
        _ viewModel: ItemPickerViewModel,
        item: ItemPickerItem,
        selected: Bool,
        indexInSelectedItems _: Int
    ) {
        guard viewModel.multiselect else { return }

        // 1. for multiselect we need to reload rows that are affected by selection
        let indexPath = IndexPath(item: viewModel.filteredItems.firstIndex(of: item) ?? 0, section: 0)
        tableView.reloadRows(at: [indexPath], with: .automatic)

        // 2. show/hide the selected items view depending on the list being not empty
        updateSelectedItemsVisibility(itemSelected: selected)
    }

    func updateSelectedItemsVisibility(itemSelected selected: Bool) {
        guard let selectedView = selectedView else { return }
        // only handle first selected item (show items) or last unselected (hide items)
        guard (selected == true && viewModel.selectedItems.count == 1)
            || (selected == false && viewModel.selectedItems.count == 0) else { return }

        selectedView.visibleStateWillTransition()
        if selected {
            // showing the users
            headerHeightConstraint?.update(offset: ItemPickerCardViewController.headerHeightWithSelectedItems)
            // first animate the header height
            UIView.animate(withDuration: 0.1) {
                self.view.layoutIfNeeded()
            } completion: { [weak self] _ in
                // when enough room show the selected users
                selectedView.setVisible(selected, animated: true)
                self?.updateHeaderShadow()
            }
        } else {
            // first hide the users
            selectedView.setVisible(false, animated: true) {
                // then animate the header to its new height
                self.headerHeightConstraint?.update(offset: ItemPickerCardViewController.headerHeight)
                UIView.animate(withDuration: 0.1) {
                    self.view.layoutIfNeeded()
                } completion: { [weak self] _ in
                    self?.updateHeaderShadow()
                }
            }
        }
    }
}

// MARK: - filtering items

extension ItemPickerCardViewController: SearchViewDelegate {
    func searchView(_: SearchView, textDidChange text: String) {
        viewModel.filter(by: text)
        tableView.reloadData()
    }
}

// MARK: - items table view delegate / data source

extension ItemPickerCardViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        1
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        viewModel.filteredItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: ItemPickerTableViewCell.Variant.identifier(forMultiselect: viewModel.multiselect),
            for: indexPath
        ) as! ItemPickerTableViewCell
        let item = viewModel.filteredItems[indexPath.row]
        cell.setItem(item)
        return cell
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // this should be considered a hack - there's no easy way of adding a border around the section in table view
        tableView.addBackgroundWithBorder(
            forCell: cell,
            forRowAt: indexPath,
            backgroundColor: .dynamic(.Neutral_09),
            borderColor: .dynamic(.Neutral_07),
            selectedBackgroundColor: .dynamic(.Neutral_08)
        )
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if viewModel.multiselect {
            let item = viewModel.filteredItems[indexPath.row]
            viewModel.set(itemWithId: item.id, selected: !item.selected)
            tableView.reloadRows(at: [indexPath], with: .automatic)
        } else {
            let item = viewModel.filteredItems[indexPath.row]
            if !item.selected {
                viewModel.set(itemWithId: item.id, selected: true)
            }
            dismissCard()
            onClose?()
        }
    }

    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        CGFloat.leastNormalMagnitude
    }

    func tableView(_: UITableView, heightForFooterInSection _: Int) -> CGFloat {
        // distance between sections
        16
    }

    func tableView(_: UITableView, viewForFooterInSection _: Int) -> UIView? {
        UIView()
    }
}
