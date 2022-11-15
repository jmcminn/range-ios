import FirebaseFirestore
import Foundation
@testable import Range
import XCTest

/// Test implementation of `FirestoreCommandContext` that tracks the invoked methods
/// and answers to `exists` calls based on predefined set of existing documents
class TestFirestoreCommandContext: FirestoreCommandContext {
    private let docs: [FirestoreDocument: Any]

    /// transactional operation type
    enum OperationType: Equatable {
        case set, update
    }

    /// Recorded setting or updating data on firestore context
    struct Operation: CustomDebugStringConvertible {
        var doc: FirestoreDocument
        var op: OperationType
        var data: [String: Any]
        var debugDescription: String { "\(doc.id).\(op)(\(data))" }

        /// helper init functions for better tests readability
        static func set(_ doc: FirestoreDocument, _ data: [String: Any]) -> Operation {
            Operation(doc: doc, op: .set, data: data)
        }

        static func update(_ doc: FirestoreDocument, _ data: [String: Any]) -> Operation {
            Operation(doc: doc, op: .update, data: data)
        }
    }

    /// operations performed on this context
    private(set) var operations = [Operation]()

    /// Initializer
    /// - parameters docs -  will return `true` from `exists` when asked for one of these
    /// - parameters docsData - this does the same as docs, but in addition it also return given data from `getDocument`
    init(docs: [FirestoreDocument], docsData: [FirestoreDocument: Any] = [:]) {
        var allDocs = [FirestoreDocument: Any]()
        docs.forEach { k in allDocs[k] = NSNull() }
        docsData.forEach { k, v in allDocs[k] = v }
        self.docs = allDocs
    }

    func exists(_ doc: FirestoreDocument) throws -> Bool {
        docs[doc] != nil
    }

    func getDocument<T>(_ doc: FirestoreDocument, as _: T.Type) throws -> T? where T: Decodable {
        guard try exists(doc) else { return nil }
        guard let doc = docs[doc] as? T else {
            throw "doc \(doc) has not type \(T.self)"
        }
        return doc
    }

    func setData(_ data: [String: Any], forDocument doc: FirestoreDocument) {
        operations.append(Operation(doc: doc, op: .set, data: data))
    }

    func setData<T>(from value: T, forDocument doc: FirestoreDocument) throws where T: Encodable {
        setData(try Firestore.Encoder().encode(value), forDocument: doc)
    }

    func updateData(_ data: [String: Any], forDocument doc: FirestoreDocument) {
        operations.append(Operation(doc: doc, op: .update, data: data))
    }
}

/// Compare 2 firestore operations and assert on all the fields (and all values in the operation data)
/// the file and line params are needed in function parameters and all XCT calls to report the assertion failure in place of function call (so
/// in test) and not here...
func AssertOperationsEqual(
    _ op1: TestFirestoreCommandContext.Operation, _ op2: TestFirestoreCommandContext.Operation,
    file: StaticString = #file, line: UInt = #line
) {
    XCTAssertEqual(op1.doc, op2.doc, file: file, line: line)
    XCTAssertEqual(op1.op, op2.op, file: file, line: line)

    let keysDiff = Set(op1.data.keys).symmetricDifference(op2.data.keys)
    if !keysDiff.isEmpty {
        XCTFail("different keys in data: \(keysDiff)", file: file, line: line)
    }
    // just a brute force check for all supported types (as there's no way to compare
    // Any (or Equatable) of different types
    for (key, v1) in op1.data {
        guard let v2 = op2.data[key] else { XCTFail("Value missing for \(key)", file: file, line: line); return }
        switch v1 {
        case let v as String: XCTAssertEqual(v, try XCTUnwrap(v2 as? String), "key: \(key)", file: file, line: line)
        case let v as Double:
            if let v2Bool = v2 as? Bool {
                // for bools, the v1 is being recognized as Double, so if v2 is a bool convert it
                // do Double for comparison
                XCTAssertEqual(v, v2Bool ? 1.0 : 0.0, "key: \(key)", file: file, line: line)
            } else {
                XCTAssertEqual(v, try XCTUnwrap(v2 as? Double), "key: \(key)", file: file, line: line)
            }
        case let v as Int: XCTAssertEqual(v, try XCTUnwrap(v2 as? Int), "key: \(key)", file: file, line: line)
        case let v as [String]: XCTAssertEqual(v, try XCTUnwrap(v2 as? [String]), "key: \(key)", file: file, line: line)
        case let v as FieldValue: XCTAssertEqual(v, try XCTUnwrap(v2 as? FieldValue), "key: \(key)", file: file,
                                                 line: line)
        case let v as Timestamp: XCTAssertEqual(v, try XCTUnwrap(v2 as? Timestamp), "key: \(key)", file: file,
                                                line: line)
        case let v as Bool: XCTAssertEqual(v, try XCTUnwrap(v2 as? Bool), "key: \(key)", file: file, line: line)
        default: XCTFail("Not supported data value type: \(type(of: v1)), value: \(v1), key: \(key)",
                         file: file, line: line)
        }
    }
}
