import Foundation

import RealmSwift

/// Protocol to ensure that object provides the id, needed for `updateArray`
protocol WithId {
    var id: String { get }
}

/// Generic helper function that updates given array (input) with Realm changes provided in results + deletions/insertions/modifications indices.
/// Instead of directly converting `updated` results to output, it uses `input` to only add/remove/modify the elements that actually changed.
/// The convert function is required to convert from the Realm result to input/output array type
/// see: https://www.mongodb.com/docs/realm/sdk/swift/examples/react-to-changes/#register-a-collection-change-listener
/// - Parameters:
///     - input:    initial state before applying the updates
///     - updated: the full updated results
///     - deletions: indices of deleted objects
///     - insertions: indices of inserted objects
///     - modifications: indices of modified objects
///     - covert: function to convert from the updated results objects to input/output array object type
/// - Returns
///   - the modified input array (copy as arrays are value types)
func updateArray<T: WithId, S: WithId>(
    _ input: [T],
    from updated: Results<S>,
    deletions: [Int],
    insertions: [Int],
    modifications: [Int],
    convert: (S) -> T?
) -> [T] {
    var output = input
    // first deletions
    // sorted descending so we can remove indices from the last to first
    for deletionIndex in deletions.sorted(by: >) {
        // remove the existing element
        output.remove(at: deletionIndex)
    }
    // then insertions
    for insertionIndex in insertions {
        // create new element
        if let element = convert(updated[insertionIndex]) {
            output.append(element)
        }
    }
    // then modifications
    // map of result.id => index in updated
    var modificationsMap = [String: Int]()
    modifications.forEach { modificationIndex in
        modificationsMap[updated[modificationIndex].id] = modificationIndex
    }
    // recreate elements for modified results
    output = output.compactMap { element in
        guard let resultIndex = modificationsMap[element.id] else { return element }
        return convert(updated[resultIndex])
    }
    return output
}
