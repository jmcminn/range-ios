import Algorithms
import Foundation
import RealmSwift

/// View model for list of tags and support for selecting/deselecting tags
class TagsViewModel: NSObject {
    /// all tags whether selected or not
    private(set) var allTags: [TagViewModel]
    /// For fast tag lookup by id
    private var allTagsIndex: [String: TagViewModel]
    /// up to 10 recently applied tags for current project (this is the reversed UserDefaults.recentTagIds, as we want the most recent as first)
    private(set) var recentTags: [TagViewModel]
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

    init(model: ProjectModel, initialSelectedTags: [TagViewModel] = []) {
        let nameSort = SortDescriptor(\TagViewModel.name, comparator: .localizedStandard)
        allTags = model.mainRealm.objects(Tag.self)
            .where { $0.placeholder == false }
            .map { TagViewModel(fromTag: $0) }
            .sorted(using: nameSort)

        mostUsedTags = Array(allTags
            .filter { $0.usageCount > 0 }
            .sorted(by: { $0.usageCount >= $1.usageCount })
            .prefix(10))

        let allTagsIndex = Dictionary(uniqueKeysWithValues: zip(allTags.map(\.id), allTags))

        recentTags = UserDefaults.recentTagIds(forProjectId: model.projectId)
            .compactMap { allTagsIndex[$0] }
            .reversed()

        self.allTagsIndex = allTagsIndex

        super.init()

        // initialSelectedTags might be new tags or existing tags that need to be preselected

        initialSelectedTags.forEach {
            self.add(tag: $0)
            self.set(tagWithId: $0.id, selected: true)
        }
    }

    /// Add delegate
    /// No option for removal as delegates are stored weakly
    func addDelegate(_ delegate: TagsViewModelDelegate) {
        delegates.add(delegate)
    }

    /// Mark tag with given id as selected/deselected and notify delegates
    /// If tag with given id is not present it's ignored
    func set(tagWithId tagId: String, selected: Bool) {
        // find tag with matching id in this view model tags
        guard let tag = allTagsIndex[tagId] else { return }
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
        guard allTagsIndex[tag.id] == nil else { return }
        // this gives a binary search result for insertion point by finding the index of the first
        // tag with a name "higher" than the new tag name
        let insertionIndex = allTags.partitioningIndex {
            nameSort.compare($0, tag) == .orderedDescending
        }
        allTags.insert(tag, at: insertionIndex)
        allTagsIndex[tag.id] = tag
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
class TagViewModel: NSObject, Codable {
    let id: String
    @objc let name: String
    /// to how many object the tag is applied
    let usageCount: Int
    /// whether this is a new tag that should be created in the db
    let newTag: Bool
    /// for searching we store a version of string that is diacriticInsensitive and caseInsensitive
    let searchName: String
    @objc fileprivate(set) dynamic var selected: Bool = false

    /// Initializer for existing tags
    /// - Parameters:
    ///   - id: id
    ///   - name: name of the tag
    ///   - usageCount: usage count
    ///   - newTag: whether this is a new tag to be created in the db
    init(
        id: String,
        name: String,
        usageCount: Int,
        newTag: Bool = false
    ) {
        self.id = id
        self.name = name
        self.usageCount = usageCount
        self.newTag = newTag
        searchName = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }

    /// Convenience initializer from the model Tag
    convenience init(fromTag tag: Tag) {
        self.init(id: tag.id, name: tag.name, usageCount: tag.usageCount)
    }

    /// Convenience initializer for new tags with auto generated id and given name
    convenience init(newTagWithName name: String) {
        self.init(id: generateRealmId(), name: name, usageCount: 0, newTag: true)
    }

    /// equatable to check for id only
    static func == (lhs: TagViewModel, rhs: TagViewModel) -> Bool {
        lhs.id == rhs.id
    }

    override var description: String {
        "'\(name)'[\(id.prefix(8))]"
    }
}
