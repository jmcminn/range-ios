import Foundation

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
    func viewModel(_ viewModel: TagsViewModel, tag: TagViewModel, selected: Bool, indexInSelectedTags: Int)
}

/// View model for list of tags and support for selecting/deselecting tags
class TagsViewModel: NSObject {
    let allTags: [TagViewModel]
    private let allTagsIndex: [String: TagViewModel]
    private(set) var selectedTags: [TagViewModel] = []

    /// Allows for multiple delegates
    private var delegates = NSHashTable<TagsViewModelDelegate>.weakObjects()

    init(model: ProjectModel) {
        let nameSort = SortDescriptor(\TagViewModel.name, comparator: .localizedStandard)
        allTags = model.mainRealm.objects(Tag.self)
            .map { TagViewModel(id: $0.id, name: $0.name) }
            .sorted(using: nameSort)
        allTagsIndex = Dictionary(uniqueKeysWithValues: zip(allTags.map(\.id), allTags))
        super.init()
    }

    /// Add delegate
    /// No option for removal as delegates are stored weakly
    func addDelegate(_ delegate: TagsViewModelDelegate) {
        delegates.add(delegate)
    }

    /// Mark tag as selected/deselected and notify delegates
    func set(tag: TagViewModel, selected: Bool) {
        tag.selected = selected

        if tag.selected {
            // insert as last tag in selected list
            selectedTags.append(tag)
            let insertIndex = selectedTags.count - 1
            delegates.allObjects
                .forEach { $0.viewModel(self, tag: tag, selected: true, indexInSelectedTags: insertIndex) }
        } else {
            if let deleteIndex = selectedTags.firstIndex(of: tag) {
                selectedTags.remove(at: deleteIndex)
                delegates.allObjects
                    .forEach { $0.viewModel(self, tag: tag, selected: false, indexInSelectedTags: deleteIndex) }
            }
        }
    }
}

/// View model for a tag with selection support
class TagViewModel: NSObject {
    let id: String
    @objc let name: String
    @objc fileprivate(set) dynamic var selected: Bool = false
    init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    /// equatable to check for id only
    static func == (lhs: TagViewModel, rhs: TagViewModel) -> Bool {
        lhs.id == rhs.id
    }
}
