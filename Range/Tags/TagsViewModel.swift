import Algorithms
import Foundation

/// View model for list of tags and support for selecting/deselecting tags
class TagsViewModel: NSObject {
    /// all tags whether selected or not
    private(set) var allTags: [TagViewModel]
    /// up to 10 recently applied tags for current project
    private(set) var lastAppliedTags: [TagViewModel]
    /// up to 10 most applied tags for current project
    private(set) var mostUsedTags: [TagViewModel]
    /// a subset of all tags storing selected tags in order they were being selected
    private(set) var selectedTags: [TagViewModel] = []
    /// filter to be used on `allTags` to derive `filteredTags`
    private(set) var filterString: String = ""
    /// the trimmed version of the filterString, to be used for creating a new tag and check for direct match in filtered tags
    private(set) var filterStringTrimmed: String = ""
    /// a subset of all tags matching the current filter in the order as in `allTags`
    private(set) var filteredTags: [TagViewModel] = []
    /// whether `filteredTags` have a match that directly matches `filterString`
    private(set) var filteredTagsContainDirectMatch: Bool = false

    /// used for sorting the tags by name
    private let nameSort = SortDescriptor(\TagViewModel.name, comparator: .localizedStandard)

    /// Allows for multiple delegates
    private var delegates = NSHashTable<TagsViewModelDelegate>.weakObjects()

    init(model: ProjectModel) {
        let nameSort = SortDescriptor(\TagViewModel.name, comparator: .localizedStandard)
        allTags = model.mainRealm.objects(Tag.self)
            .map { TagViewModel(id: $0.id, name: $0.name, lastApplied: $0.lastApplied, usageCount: $0.usageCount) }
            .sorted(using: nameSort)

        lastAppliedTags = Array(allTags
            .filter { $0.lastApplied != nil }
            .sorted(by: { $0.lastApplied! > $1.lastApplied! })
            .prefix(10))

        mostUsedTags = Array(allTags
            .filter { $0.usageCount > 0 }
            .sorted(by: { $0.usageCount >= $1.usageCount })
            .prefix(10))

        super.init()
    }

    /// Add delegate
    /// No option for removal as delegates are stored weakly
    func addDelegate(_ delegate: TagsViewModelDelegate) {
        delegates.add(delegate)
    }

    /// Mark tag as selected/deselected and notify delegates
    /// - Warning: TagsViewModel operates on references, so the tag passed to this method needs to be obtained from the
    /// viewmodel alltags, selectedtags, etc... and not a new object
    func set(tag: TagViewModel, selected: Bool) {
        tag.selected = selected

        if tag.selected {
            // insert as last tag in selected list
            selectedTags.append(tag)
            let insertIndex = selectedTags.count - 1
            delegates.allObjects
                .forEach { $0.tagsViewModel?(self, tag: tag, selected: true, indexInSelectedTags: insertIndex) }
        } else {
            if let deleteIndex = selectedTags.firstIndex(of: tag) {
                selectedTags.remove(at: deleteIndex)
                delegates.allObjects
                    .forEach { $0.tagsViewModel?(self, tag: tag, selected: false, indexInSelectedTags: deleteIndex) }
            }
        }
    }

    /// filter `allTags` by given String and store results in `filteredTags`
    func filter(by filterString: String) {
        self.filterString = filterString
        filterStringTrimmed = filterString.trimmingCharacters(in: .whitespacesAndNewlines)
        // remove diacritics and make it lowercase
        let filterTerm = filterStringTrimmed
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        // split by whitespace to multiple terms
        let filterTerms = filterTerm.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        // tag matches if it contains all the filterTerms
        filteredTags = allTags.filter { tag in
            // has to contain all of the search terms
            filterTerms.allSatisfy { tag.searchName.contains($0) }
        }
        filteredTagsContainDirectMatch = filteredTags.contains(where: { $0.name == self.filterStringTrimmed })
        delegates.allObjects.forEach { $0.tagsViewModelFiltered?(self) }
    }

    func add(tag: TagViewModel) {
        // this gives a binary search result for insertion point by finding the index of the first
        // tag with a name "higher" than the new tag name
        let insertionIndex = allTags.partitioningIndex {
            nameSort.compare($0, tag) == .orderedDescending
        }
        allTags.insert(tag, at: insertionIndex)
    }
}

/// Delegate for `TagsViewModel`
///
/// see `SearchViewDelegate` for why it's @objc protocol
@objc protocol TagsViewModelDelegate: AnyObject {
    /// notifies that the given tag was selected/deselected
    /// - Parameters:
    ///     - viewModel
    ///     - tag selected tag
    ///     - selected: selected or deselected
    ///     - indexInSelectedTags: it's new index in the `selectedTags`
    @objc optional func tagsViewModel(
        _ viewModel: TagsViewModel,
        tag: TagViewModel,
        selected: Bool,
        indexInSelectedTags: Int
    )

    /// notifies that a filter was applied (or removed) from the viewModel.
    @objc optional func tagsViewModelFiltered(_ viewModel: TagsViewModel)
}

/// View model for a tag with selection support
class TagViewModel: NSObject {
    let id: String
    @objc let name: String
    let lastApplied: TimeInterval?
    /// to how many object the tag is applied
    let usageCount: Int
    /// for searching we store a version of string that is diacriticInsensitive and caseInsensitive
    let searchName: String
    @objc fileprivate(set) dynamic var selected: Bool = false

    // TODO: 44 tag with local id should be marked as "local" when saving to realm
    /// - Parameters:
    ///   - id: if not provided then automatically created for new tags
    ///   - name: name of the tag
    ///   - lastApplied: if not provided then set to 0 for new tags, meaning not applied yet
    init(
        id: String = UUID().uuidString.lowercased(),
        name: String,
        lastApplied: TimeInterval? = nil,
        usageCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.lastApplied = lastApplied
        self.usageCount = usageCount
        searchName = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }

    /// equatable to check for id only
    static func == (lhs: TagViewModel, rhs: TagViewModel) -> Bool {
        lhs.id == rhs.id
    }

    override var description: String {
        "'\(name)'[\(id.prefix(8))]"
    }
}
