import Foundation

/// Merges two sorted arrays into the result sorted array.
/// The first argument is a type of the arrays element as in Swift you cannot explicitely specialize a generic function, the type has to be inferred
/// from the parameters so we need to pass the parameter with given type.
func _mergeSortedArrays<T: Comparable>(_: T.Type, _ left: [T], _ right: [T], ascending: Bool = true) -> [T] {
    var leftIndex = 0
    var rightIndex = 0

    var sortedArray: [T] = []
    sortedArray.reserveCapacity(left.count + right.count)

    // both arrays have elements
    while leftIndex < left.count, rightIndex < right.count {
        let leftElement = left[leftIndex]
        let rightElement = right[rightIndex]

        if leftElement < rightElement {
            if ascending {
                sortedArray.append(leftElement)
                leftIndex += 1
            } else {
                sortedArray.append(rightElement)
                rightIndex += 1
            }
        } else if leftElement > rightElement {
            if ascending {
                sortedArray.append(rightElement)
                rightIndex += 1
            } else {
                sortedArray.append(leftElement)
                leftIndex += 1
            }
        } else {
            sortedArray.append(leftElement)
            leftIndex += 1
            sortedArray.append(rightElement)
            rightIndex += 1
        }
    }

    // whatever is left in the left array
    while leftIndex < left.count {
        sortedArray.append(left[leftIndex])
        leftIndex += 1
    }

    // whatever is left in the right array
    while rightIndex < right.count {
        sortedArray.append(right[rightIndex])
        rightIndex += 1
    }

    return sortedArray
}
