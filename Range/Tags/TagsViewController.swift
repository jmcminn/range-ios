import UIKit

/// A table view with 3 sections: recent, popular and all project tags
class TagsViewController: UIViewController {
    /// Sections for not filtered view
    private enum Section {
        case recent
        case popular
        case all

        func localizedTitle() -> String {
            switch self {
            case .recent:
                return String(localized: "Recent Tags")
            case .popular:
                return String(localized: "Popular Tags")
            case .all:
                return String(localized: "All Tags (A-Z)")
            }
        }
    }

    unowned let viewModel: TagsViewModel
    let tableView: UITableView
    private let notFilteredSections: [Section]
    /// if the "show more" was enabled for given section. "Show more" button shows when there's more
    /// than 4 recent/popular tags, but once user selects this option it shows all of the recent/popular tags
    /// and doesn't allow to hide more
    private var showingMore: [Section: Bool] = [:]

    /// By default show only up to this number of recent tags and add "show more" button if there's more
    private let showLessTagsLimit = 4

    init(viewModel: TagsViewModel) {
        self.viewModel = viewModel
        tableView = UITableView(frame: .zero, style: .grouped) // grouped so the section headers don't float
        notFilteredSections = TagsViewController.getNotFilteredSections(viewModel: viewModel)
        super.init(nibName: nil, bundle: nil)

        viewModel.addDelegate(self)
    }

    private static func getNotFilteredSections(viewModel: TagsViewModel) -> [Section] {
        var sections: [Section] = []
        if !viewModel.lastAppliedTags.isEmpty {
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

        view.backgroundColor = .dynamicColor(light: .Neutral_01, dark: .Neutral_10)

        tableView.backgroundColor = view.backgroundColor
        tableView.sectionHeaderTopPadding = 0
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.register(TagTableViewCell.self, forCellReuseIdentifier: "TagCell")
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

extension TagsViewController: TagsViewModelDelegate {
    /// reload table view when view model filtered - either show the filtered tags or all tags if filter is empty
    func tagsViewModelFiltered(_: TagsViewModel) {
        tableView.reloadData()
    }

    var showFilteredTags: Bool {
        !viewModel.filterStringTrimmed.isEmpty
    }
}

// MARK: - UITableView delegate and data source

extension TagsViewController: UITableViewDelegate, UITableViewDataSource {
    /// for filtered tags the last row is the "create tag" row
    func isCreateTagRow(_ indexPath: IndexPath) -> Bool {
        showFilteredTags && indexPath.row == viewModel.filteredTags.count
    }

    /// Return the appropriate tags from view model for given section number
    func tags(inNonFilteredSection section: Int) -> [TagViewModel] {
        switch notFilteredSections[section] {
        case .recent:
            return viewModel.lastAppliedTags
        case .popular:
            return viewModel.mostUsedTags
        case .all:
            return viewModel.allTags
        }
    }

    /// whether to show "show more" button for given section (and limit the number of tags to `showLessTagsLimit`)
    func showMoreButtonForSection(sectionNumber: Int) -> Bool {
        // show all tags for .all section
        let section = notFilteredSections[sectionNumber]
        guard section != .all else { return false }

        let tagsCount = tags(inNonFilteredSection: sectionNumber).count

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
        !showFilteredTags
            && showMoreButtonForSection(sectionNumber: indexPath.section)
            && indexPath.row == showLessTagsLimit
    }

    /// Convenience method to get tag based on IndexPath
    func tag(for indexPath: IndexPath) -> TagViewModel {
        showFilteredTags
            ? viewModel.filteredTags[indexPath.row]
            : tags(inNonFilteredSection: indexPath.section)[indexPath.row]
    }

    func numberOfSections(in _: UITableView) -> Int {
        showFilteredTags
            ? 1
            : notFilteredSections.count
    }

    func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        // no header for filtered tags
        guard !showFilteredTags else { return nil }
        return notFilteredSections[section].localizedTitle()
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        if showFilteredTags {
            // if there's no direct match in filtered tags then add one more row for creating tag
            return viewModel.filteredTagsContainDirectMatch
                ? viewModel.filteredTags.count
                : viewModel.filteredTags.count + 1
        }
        if showMoreButtonForSection(sectionNumber: section) {
            return showLessTagsLimit + 1
        } else {
            return tags(inNonFilteredSection: section).count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if isCreateTagRow(indexPath) {
            let cell = tableView.dequeueReusableCell(withIdentifier: "TagCell", for: indexPath) as! TagTableViewCell
            cell.displayCreateNewTag(viewModel.filterStringTrimmed)
            return cell
        } else if isShowMoreRow(indexPath) {
            let cell = tableView.dequeueReusableCell(withIdentifier: "ShowMoreCell", for: indexPath)
            cell.backgroundColor = UIColor.clear // bg is covered by addBackgroundWithBorder in willDisplay:
            cell.textLabel?.text = "Show more"
            cell.textLabel?.textAlignment = .center
            cell.textLabel?.textColor = .Primary_Blue_04
            let font = UIFont.preferredFont(forTextStyle: .subheadline)
            let boldFont = UIFont(descriptor: font.fontDescriptor.withSymbolicTraits(.traitBold)!, size: 0)
            cell.textLabel?.font = boldFont
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "TagCell", for: indexPath) as! TagTableViewCell
            cell.tagViewModel = tag(for: indexPath)
            return cell
        }
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // this should be considered a hack - there's no easy way of adding a border around the section in table view
        tableView.addBackgroundWithBorder(
            forCell: cell,
            forRowAt: indexPath,
            // UIColor.dynamicColor didn't work for overrideUserInterfaceStyle = .dark
            backgroundColor: chooseColor(light: .Neutral_02, dark: .Neutral_09),
            borderColor: chooseColor(light: .Neutral_03, dark: .Neutral_08),
            selectedBackgroundColor: .systemGray4 // this is what selectedBackgroundView uses by default
        )
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = UIView()
        let label = UILabel(frame: .zero)
        label.text = self.tableView(tableView, titleForHeaderInSection: section)
        let font = UIFont.preferredFont(forTextStyle: .subheadline)
        let boldFont = UIFont(descriptor: font.fontDescriptor.withSymbolicTraits(.traitBold)!, size: 0)
        label.font = boldFont
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .dynamicColor(light: .Neutral_07, dark: .Neutral_05)
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
            let tag = TagViewModel(name: viewModel.filterStringTrimmed)
            // add new tag
            viewModel.add(tag: tag)
            // mark it selected
            viewModel.set(tagWithId: tag.id, selected: true)
            // and remove the filter
            viewModel.filter(by: "")
            tableView.deselectRow(at: indexPath, animated: true)
        } else if isShowMoreRow(indexPath) {
            showingMore[notFilteredSections[indexPath.section]] = true
            // insert rows from
            tableView.beginUpdates()
            // reload the "show more" row
            tableView.reloadRows(at: [indexPath], with: .automatic)
            // insert remaining rows
            let indexPaths =
                (showLessTagsLimit + 1 ..< tags(inNonFilteredSection: indexPath.section).count)
                    .map { IndexPath(row: $0, section: indexPath.section) }
            tableView.insertRows(at: indexPaths, with: .bottom)
            tableView.endUpdates()
        } else {
            let tag = tag(for: indexPath)
            viewModel.set(tagWithId: tag.id, selected: !tag.selected)
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }

    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        // no header for filtered tags
        showFilteredTags ? 0 : 36
    }

    func tableView(_: UITableView, heightForFooterInSection _: Int) -> CGFloat {
        16
    }
}
