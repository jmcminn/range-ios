@testable import Range
import XCTest

final class AnnotationsTest: XCTestCase {
    func testPersisting() throws {
        let annotations = Annotations(width: 2048, height: 1536, scale: 2.0, [
            ScribbleAnnotation(
                id: "annotation1",
                path: RangeBezierPath(elements: [
                    .move(to: CGPoint(x: 10, y: 10)),
                    .addLine(to: CGPoint(x: 20, y: 5)),
                ]),
                lineWidth: 6,
                color: .black
            ),
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

    func testPersisting_roundingNumbers() throws {
        let annotations = Annotations(width: 2048, height: 1536, scale: 2.66666666, [
            ArrowAnnotation(id: "1", startPoint: CGPoint(x: 1.123, y: 1.123), endPoint: CGPoint(x: 2.234, y: 2.234),
                            lineWidth: 2.23232323, color: .white),
            LineAnnotation(id: "2", startPoint: CGPoint(x: 10.666, y: 10.666), endPoint: CGPoint(x: 20.333, y: 21.001),
                           lineWidth: 9.999999999, color: .black),
            ScribbleAnnotation(id: "3", path: RangeBezierPath(elements: [
                .move(to: CGPoint(x: 10.6666, y: 10.6666)),
                .addLine(to: CGPoint(x: 20.1234, y: 5.1233)),
            ]), lineWidth: 6.01010101, color: .black),
            TextAnnotation(id: "4", text: "text", position: CGPoint(x: 30.888, y: 40.8218),
                           fontSize: 21.21212121, color: .black),
        ])

        // 1 convert to persisted value
        let persistedValue = annotations.persistableValue
        XCTAssertEqual(
            persistedValue,
            ##"{"annotations":["## +
                ##"{"endPoint":[2.23,2.23],"hexColor":"#ffffff","id":"1","lineWidth":2.232323,"startPoint":[1.12,1.12],"type":"arrow"},"## +
                ##"{"endPoint":[20.33,21],"hexColor":"#000000","id":"2","lineWidth":10,"startPoint":[10.67,10.67],"type":"line"},"## +
                ##"{"hexColor":"#000000","id":"3","lineWidth":6.010101,"path":"M10.67,10.67 L20.12,5.12","type":"scribble"},"## +
                ##"{"fontSize":21.212121,"hexColor":"#000000","id":"4","position":[30.89,40.82],"text":"text","type":"text"}"## +
                ##"],"format":"https:\/\/range.io\/photo-annotations\/v1","height":1536,"scale":2.666667,"width":2048}"##
        )
    }
}
