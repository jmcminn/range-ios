import UIKit

/// A table view with 4 sections: untagged option, recent, popular and all project tags
/// Allows for selecting/deselecting tags for given TagsViewModel
class TagsSelectionViewController: UIViewController {
    /// Sections for not filtered view
    private enum Section {
        case untagged // special section to select TagViewModel.untagged, only shown when showUntaggedOption = true
        case recent
        case popular
        case all
        case filtered

        func localizedTitle() -> String? {
            switch self {
            case .untagged: return nil
            case .recent: return String(localized: "Recent Tags")
            case .popular: return String(localized: "Popular Tags")
            case .all: return String(localized: "All Tags (A-Z)")
            case .filtered: return nil
            }
        }
    }

    unowned let viewModel: TagsViewModel
    let tableView: UITableView
    // map of filtered (Bool) => [Section]
    private let allSections: [Bool: [Section]]
    /// if the "show more" was enabled for given section. "Show more" button shows when there's more
    /// than 4 recent/popular tags, but once user selects this option it shows all of the recent/popular tags
    /// and doesn't allow to hide more
    private var showingMore: [Section: Bool] = [:]

    /// By default show only up to this number of recent tags and add "show more" button if there's more
    private let showLessTagsLimit = 5

    /// Show a special row when there's no direct match in filtered tags
    var showCreateTag: Bool = true

    /// Show a special row (in the 1st section) that allows for selecting TagViewModel.untagged - for filtering pins that have no tags
    private let showUntaggedOption: Bool

    /// whether to show the tag count
    var showTagCount: Bool = true

    init(viewModel: TagsViewModel, showUntaggedOption: Bool = false) {
        self.viewModel = viewModel
        self.showUntaggedOption = showUntaggedOption
        tableView = UITableView(frame: .zero, style: .grouped) // grouped so the section headers don't float
        allSections = [
            false: TagsSelectionViewController.getNotFilteredSections(
                viewModel: viewModel,
                showUntaggedOption: showUntaggedOption
            ),
            true: TagsSelectionViewController.getFilteredSections(
                viewModel: viewModel,
                showUntaggedOption: showUntaggedOption
            ),
        ]
        super.init(nibName: nil, bundle: nil)

        viewModel.addDelegate(self)
    }

    private static func getFilteredSections(viewModel _: TagsViewModel, showUntaggedOption: Bool) -> [Section] {
        var sections: [Section] = []
        if showUntaggedOption {
            sections.append(.untagged)
        }
        sections.append(.filtered)
        return sections
    }

    private static func getNotFilteredSections(viewModel: TagsViewModel, showUntaggedOption: Bool) -> [Section] {
        var sections: [Section] = []
        if showUntaggedOption {
            sections.append(.untagged)
        }
        if !viewModel.recentTags.isEmpty {
            sections.append(.recent)
        }
        if !viewModel.mostUsedTags.isEmpty {
            sections.append(.popular)
        }
        sections.append(.all)
        return sections
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .dynamic(.Neutral_10)

        tableView.backgroundColor = view.backgroundColor
        tableView.sectionHeaderTopPadding = 0
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.register(TagSelectionTableViewCell.self, forCellReuseIdentifier: "TagCell")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ShowMoreCell")
        view.addSubview(tableView)

        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        tableView.reloadData()
    }

    override func traitCollectionDidChange(_: UITraitCollection?) {
        // update the border color for cells
        tableView.reloadData()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - TagsViewModel

extension TagsSelectionViewController: TagsViewModelDelegate {
    /// reload table view when view model filtered - either show the filtered tags or all tags if filter is empty
    func tagsViewModelFiltered(_: TagsViewModel) {
        tableView.reloadData()
    }

    var showFilteredTags: Bool {
        !viewModel.filterStringTrimmed.isEmpty
    }
}

// MARK: - UITableView delegate and data source

extension TagsSelectionViewController: UITableViewDelegate, UITableViewDataSource {
    /// Current sections based on `showFilteredTags` value
    private var sections: [Section] {
        allSections[showFilteredTags]!
    }

    /// for filtered tags the last row is the "create tag" row
    func isCreateTagRow(_ indexPath: IndexPath) -> Bool {
        let section = sections[indexPath.section]
        return section == .filtered && indexPath.row == tags(inSection: section).count
    }

    /// Return the appropriate tags from view model for given section in current sections
    private func tags(inSection section: Section) -> [TagViewModel] {
        switch section {
        case .untagged: return [viewModel.untaggedTag]
        case .recent: return viewModel.recentTags
        case .popular: return viewModel.mostUsedTags
        case .all: return viewModel.allTags
        case .filtered: return viewModel.filteredTags
        }
    }

    private func tag(forIndexPath indexPath: IndexPath) -> TagViewModel {
        tags(inSection: sections[indexPath.section])[indexPath.row]
    }

    /// whether to show "show more" button for given section (and limit the number of tags to `showLessTagsLimit`)
    private func showMoreButton(forSection section: Section) -> Bool {
        // show more only for recent and popular
        guard section == .recent || section == .popular else { return false }

        let tagsCount = tags(inSection: section).count

        if tagsCount <= showLessTagsLimit {
            return false
        } else {
            if showingMore[section] ?? false {
                return false
            } else {
                return true
            }
        }
    }

    /// for not filtered tags is it the "show more" button row
    func isShowMoreRow(_ indexPath: IndexPath) -> Bool {
        let section = sections[indexPath.section]
        return showMoreButton(forSection: section) && indexPath.row == showLessTagsLimit - 1
    }

    func numberOfSections(in _: UITableView) -> Int {
        sections.count
    }

    func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].localizedTitle()
    }

    func tableView(_: UITableView, numberOfRowsInSection sectionNumber: Int) -> Int {
        let section = sections[sectionNumber]
        if section == .filtered {
            let tagsCount = tags(inSection: section).count
            // if there's no direct match in filtered tags then add one more row for creating tag
            return viewModel.filteredTagsContainDirectMatch || !showCreateTag
                ? tagsCount
                : tagsCount + 1
        }
        if showMoreButton(forSection: section) {
            return showLessTagsLimit
        } else {
            return tags(inSection: section).count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if isCreateTagRow(indexPath) {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: "TagCell",
                for: indexPath
            ) as! TagSelectionTableViewCell
            cell.displayCreateNewTag(viewModel.filterStringTrimmed)
            return cell
        } else if isShowMoreRow(indexPath) {
            let cell = tableView.dequeueReusableCell(withIdentifier: "ShowMoreCell", for: indexPath)
            cell.backgroundColor = UIColor.clear // bg is covered by addBackgroundWithBorder in willDisplay:
            cell.textLabel?.text = "Show more"
            cell.textLabel?.textAlignment = .center
            cell.textLabel?.textColor = .Primary_Blue_04
            cell.textLabel?.font = ._preferredFont(forTextStyle: .subheadline, symbolicTraits: .traitBold)
            cell.textLabel?.adjustsFontForContentSizeCategory = true
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: "TagCell",
                for: indexPath
            ) as! TagSelectionTableViewCell
            cell.showTagCount = showTagCount
            cell.tagViewModel = tag(forIndexPath: indexPath)
            return cell
        }
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // this should be considered a hack - there's no easy way of adding a border around the section in table view
        tableView.addBackgroundWithBorder(
            forCell: cell,
            forRowAt: indexPath,
            // UIColor.dynamicColor didn't work for overrideUserInterfaceStyle = .dark
            backgroundColor: chooseColor(.Neutral_09),
            borderColor: chooseColor(.Neutral_07),
            selectedBackgroundColor: .dynamic(.Neutral_08)
        )
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = UIView()
        let label = UILabel(frame: .zero)
        label.text = self.tableView(tableView, titleForHeaderInSection: section)
        label.font = ._preferredFont(forTextStyle: .subheadline, symbolicTraits: .traitBold)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .dynamic(.Neutral_05)
        label.sizeToFit()
        label.frame.origin.x = 16
        view.addSubview(label)
        return view
    }

    func tableView(_: UITableView, viewForFooterInSection _: Int) -> UIView? {
        UIView()
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if isCreateTagRow(indexPath) {
            let tag = TagViewModel(newTagWithName: viewModel.filterStringTrimmed)
            // add new tag
            viewModel.add(tag: tag)
            // mark it selected
            viewModel.set(tagWithId: tag.id, selected: true)
            // and remove the filter
            viewModel.filter(by: "")
            tableView.deselectRow(at: indexPath, animated: true)
        } else if isShowMoreRow(indexPath) {
            let section = sections[indexPath.section]
            showingMore[section] = true
            // insert rows from
            tableView.beginUpdates()
            // reload the "show more" row
            tableView.reloadRows(at: [indexPath], with: .automatic)
            // insert remaining rows
            let indexPaths = (showLessTagsLimit ..< tags(inSection: section).count)
                .map { IndexPath(row: $0, section: indexPath.section) }
            tableView.insertRows(at: indexPaths, with: .bottom)
            tableView.endUpdates()
        } else {
            let tag = tag(forIndexPath: indexPath)
            viewModel.set(tagWithId: tag.id, selected: !tag.selected)
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }

    func tableView(_: UITableView, heightForHeaderInSection sectionNumber: Int) -> CGFloat {
        sections[sectionNumber].localizedTitle() == nil
            ? 0
            : UIFont._preferredFont(forTextStyle: .subheadline, symbolicTraits: .traitBold).lineHeight + 16
    }

    func tableView(_: UITableView, heightForFooterInSection _: Int) -> CGFloat {
        16
    }
}
