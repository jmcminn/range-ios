import UIKit

/// A table view with 3 sections: recent, popular and all project tags
class TagsViewController: UIViewController {
    unowned let viewModel: TagsViewModel
    let tableView: UITableView

    init(viewModel: TagsViewModel) {
        self.viewModel = viewModel
        tableView = UITableView(frame: .zero, style: .grouped) // grouped so the section headers don't float
        super.init(nibName: nil, bundle: nil)

        viewModel.addDelegate(self)
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

    func tag(for indexPath: IndexPath) -> TagViewModel {
        showFilteredTags
            ? viewModel.filteredTags[indexPath.row]
            : viewModel.allTags[indexPath.row]
    }

    func numberOfSections(in _: UITableView) -> Int {
        1
    }

    func tableView(_: UITableView, titleForHeaderInSection _: Int) -> String? {
        // no header for filtered tags
        guard !showFilteredTags else { return nil }
//        if section == 0 {
//            return String(localized: "Recent Tags")
//        } else if section == 1 {
//            return String(localized: "Popular Tags")
//        } else {
        return String(localized: "All Tags (A-Z)")
//        }
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
//        1
        showFilteredTags
            ? // if there's no direct match in filtered tags then add one more row for creating tag
            (viewModel.filteredTagsContainDirectMatch ? viewModel.filteredTags.count : viewModel.filteredTags
                .count + 1)
            : viewModel.allTags.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TagCell", for: indexPath) as! TagTableViewCell
        if isCreateTagRow(indexPath) {
            cell.displayCreateNewTag(viewModel.filterStringTrimmed)
        } else {
            cell.tagViewModel = tag(for: indexPath)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // this should be considered a hack - there's no easy way of adding a border around the section in table view
        tableView.addBackgroundWithBorder(
            forCell: cell,
            forRowAt: indexPath,
            backgroundColor: .dynamicColor(light: .Neutral_02, dark: .Neutral_09),
            borderColor: .dynamicColor(light: .Neutral_03, dark: .Neutral_08),
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
            viewModel.set(tag: tag, selected: true)
            // and remove the filter
            viewModel.filter(by: "")
            tableView.deselectRow(at: indexPath, animated: true)
        } else {
            let tag = tag(for: indexPath)
            viewModel.set(tag: tag, selected: !tag.selected)
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
