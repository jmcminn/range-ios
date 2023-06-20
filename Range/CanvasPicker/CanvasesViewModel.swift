import Algorithms
import Foundation
import RealmSwift

/// View model for list of canvases and support for selecting/deselecting
class CanvasesViewModel: NSObject {
    /// whether it's a multi or single select model
    let multiselect: Bool
    /// all canvases whether selected or not
    private(set) var allCanvases: [CanvasViewModel]
    /// For fast lookup by id
    private var allCanvasesIndex: [String: CanvasViewModel]
    /// a subset of all canvases storing selected ones in order they were being selected
    private(set) var selectedCanvases: [CanvasViewModel] = []
    /// filter to be used on `allCanvases` to derive `filteredCanvases`
    private(set) var filterString: String = ""
    /// a subset of all canvases matching the current filter in the order as in `allCanvases`
    private(set) var filteredCanvases: [CanvasViewModel] = []

    /// used for sorting the canvases by name
    private let nameSort = SortDescriptor(\CanvasViewModel.name, comparator: .localizedStandard)

    /// Allows for multiple delegates
    private var delegates = NSHashTable<CanvasesViewModelDelegate>.weakObjects()

    init(model: ProjectModel, multiselect: Bool) {
        self.multiselect = multiselect
        allCanvases = model.mainRealm.objects(Canvas.self)
            .where { $0.placeholder == false }
            .map { CanvasViewModel(fromCanvas: $0) }
            .sorted(using: nameSort)

        allCanvasesIndex = Dictionary(uniqueKeysWithValues: zip(allCanvases.map(\.id), allCanvases))

        super.init()

        filteredCanvases = allCanvases
    }

    /// Add delegate
    /// No option for removal as delegates are stored weakly
    func addDelegate(_ delegate: CanvasesViewModelDelegate) {
        delegates.add(delegate)
    }

    /// Mark canvas with given id as selected/deselected and notify delegates
    /// If canvas with given id is not present it's ignored
    func set(canvasWithId id: String, selected: Bool) {
        // find canvas with matching id in this view model tags
        guard let canvas = allCanvasesIndex[id] else { return }
        guard canvas.selected != selected else { return }

        // store ids to unselect at the end (after selection)
        // the unselection is done after selection so switching selection doesn't produce
        // a temporary empty selection (which doesn't work nicely with the animations
        // based on the callbacks from model).
        // TODO: Ideally all the selections/unselections  would be propagated in 1 delegate call (kind of transactional)
        let idsToUnselect: [String]?
        if selected {
            if multiselect {
                // no unselection in multiselect
                idsToUnselect = nil
            } else {
                // for single selection we unselect the previously selected
                idsToUnselect = selectedCanvases.map(\.id)
            }
        } else {
            idsToUnselect = nil
        }

        canvas.selected = selected
        if canvas.selected {
            // insert as last canvas in selected list
            selectedCanvases.append(canvas)
            let insertIndex = selectedCanvases.count - 1
            delegates.allObjects
                .forEach {
                    $0.canvasesViewModel?(self, canvas: canvas, selected: true, indexInSelectedCanvases: insertIndex)
                }
        } else {
            if let deleteIndex = selectedCanvases.firstIndex(of: canvas) {
                selectedCanvases.remove(at: deleteIndex)
                delegates.allObjects
                    .forEach {
                        $0
                            .canvasesViewModel?(
                                self,
                                canvas: canvas,
                                selected: false,
                                indexInSelectedCanvases: deleteIndex
                            )
                    }
            }
        }

        if let idsToUnselect = idsToUnselect {
            idsToUnselect.forEach { self.set(canvasWithId: $0, selected: false) }
        }
    }

    /// Unselect all selected canvases
    func clearSelection() {
        let selectedIds = selectedCanvases.map(\.id)
        selectedIds.forEach { self.set(canvasWithId: $0, selected: false) }
    }

    /// filter `allCanvases` by given String and store results in `filteredCanvases`
    func filter(by filterString: String) {
        self.filterString = filterString
        let filterStringTrimmed = filterString.trimmingCharacters(in: .whitespacesAndNewlines)
        // remove diacritics and make it lowercase
        let filterTerm = filterStringTrimmed
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        // split by whitespace to multiple terms
        let filterTerms = filterTerm.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        // canvas matches if it contains all the filterTerms
        filteredCanvases = allCanvases.filter { canvas in
            // has to contain all of the search terms
            filterTerms.allSatisfy { canvas.searchName.contains($0) }
        }
        delegates.allObjects.forEach { $0.canvasesViewModelFiltered?(self) }
    }
}

/// Delegate for `CanvasesViewModel`
///
/// see `SearchViewDelegate` for why it's @objc protocol
@objc protocol CanvasesViewModelDelegate: AnyObject {
    /// notifies that the given user was selected/deselected
    /// - Parameters:
    ///     - viewModel
    ///     - canvas selected canvase
    ///     - selected: selected or deselected
    ///     - indexInSelectedCanvases: it's new index in the `selectedCanvases`
    @objc optional func canvasesViewModel(
        _ viewModel: CanvasesViewModel,
        canvas: CanvasViewModel,
        selected: Bool,
        indexInSelectedCanvases: Int
    )

    /// notifies that a filter was applied (or removed) from the viewModel.
    @objc optional func canvasesViewModelFiltered(_ viewModel: CanvasesViewModel)
}

/// View model for canvas with selection support
class CanvasViewModel: NSObject, Codable {
    let id: String
    @objc let name: String
    /// for searching we store a version of string that is diacriticInsensitive and caseInsensitive
    let searchName: String
    @objc fileprivate(set) dynamic var selected: Bool = false

    /// Initializer for existing users
    /// - Parameters:
    ///   - id: id
    ///   - name: name of the user
    init(id: String, name: String) {
        self.id = id
        self.name = name
        searchName = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }

    /// Convenience initializer from the model Canvas
    convenience init(fromCanvas canvas: Canvas) {
        self.init(id: canvas.id, name: canvas.displayName)
    }

    /// equatable to check for id only
    static func == (lhs: CanvasViewModel, rhs: CanvasViewModel) -> Bool {
        lhs.id == rhs.id
    }

    override var description: String {
        "'\(name)'[\(id.prefix(8))]"
    }
}
