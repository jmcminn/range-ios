@testable import Range
import XCTest

final class AnnotationsTest: XCTestCase {
    func testPersisting() throws {
        let annotations = Annotations(width: 2048, height: 1536, scale: 2.0, [
            .scribble(ScribbleAnnotation(
                id: "annotation1",
                path: RangeBezierPath(elements: [
                    .move(to: CGPoint(x: 10, y: 10)),
                    .addLine(to: CGPoint(x: 20, y: 5)),
                ]),
                lineWidth: 6,
                color: .black
            )),
        ])

        // 1 convert to persisted value
        let persistedValue = annotations.persistableValue
        XCTAssertEqual(
            persistedValue,
            ##"{"annotations":[{"hexColor":"#000000","id":"annotation1","lineWidth":6,"path":"M10,10 L20,5","type":"scribble"}],"format":"https:\/\/range.io\/photo-annotations\/v1","height":1536,"scale":2,"width":2048}"##
        )

        // 2 convert back to Annotations
        let decodedAnnotations = Annotations(persistedValue: persistedValue)
        XCTAssertEqual(
            try XCTUnwrap(decodedAnnotations),
            annotations,
            "decoded annotations should equal to the persisted ones"
        )
    }
}
