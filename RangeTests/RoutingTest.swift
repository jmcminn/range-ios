import Foundation
@testable import Range
import XCTest

final class RoutingTest: XCTestCase {
    func route(_ urlString: String) -> OrgRoute? {
        routeForURL(URL(string: urlString)!)
    }

    func testRouteForURL() throws {
        XCTAssertEqual(
            route("https://development-18fcf.web.app/login"),
            nil,
            "route with no organizationId is not supported"
        )
        // organization
        XCTAssertEqual(
            route("https://development-18fcf.web.app/c39f1e8b-cabb-44c9-822e-e0d7ee92a90d"),
            OrgRoute("c39f1e8b-cabb-44c9-822e-e0d7ee92a90d", .projects),
            "empty org route defaults to projects"
        )
        XCTAssertEqual(
            route("https://development-18fcf.web.app/c39f1e8b-cabb-44c9-822e-e0d7ee92a90d/projects"),
            OrgRoute("c39f1e8b-cabb-44c9-822e-e0d7ee92a90d", .projects)
        )
        // project canvas
        XCTAssertEqual(
            route(
                "https://development-18fcf.web.app/c39f1e8b-cabb-44c9-822e-e0d7ee92a90d/474503d1-1adc-4268-88fe-2a797148f16d/f6e9f346-d51a-48ca-b372-84870444b7c8?x=-96.77528&y=32.82478&z=19.8"
            ),
            OrgRoute("c39f1e8b-cabb-44c9-822e-e0d7ee92a90d",
                     .project(ProjectRoute("474503d1-1adc-4268-88fe-2a797148f16d",
                                           .canvas("f6e9f346-d51a-48ca-b372-84870444b7c8", collaborationId: nil))))
        )
        XCTAssertEqual(
            route(
                "https://development-18fcf.web.app/c39f1e8b-cabb-44c9-822e-e0d7ee92a90d/474503d1-1adc-4268-88fe-2a797148f16d/f6e9f346-d51a-48ca-b372-84870444b7c8?x=-96.77528&y=32.82478&z=19.8&c=56a66de1-8c46-4ac0-9ce2-1ce2ca565cf1"
            ),
            OrgRoute("c39f1e8b-cabb-44c9-822e-e0d7ee92a90d",
                     .project(ProjectRoute("474503d1-1adc-4268-88fe-2a797148f16d",
                                           .canvas(
                                               "f6e9f346-d51a-48ca-b372-84870444b7c8",
                                               collaborationId: "56a66de1-8c46-4ac0-9ce2-1ce2ca565cf1"
                                           ))))
        )

        // project tasks
        XCTAssertEqual(
            route(
                "https://development-18fcf.web.app/c39f1e8b-cabb-44c9-822e-e0d7ee92a90d/474503d1-1adc-4268-88fe-2a797148f16d/list"
            ),
            OrgRoute("c39f1e8b-cabb-44c9-822e-e0d7ee92a90d",
                     .project(ProjectRoute("474503d1-1adc-4268-88fe-2a797148f16d", .tasks)))
        )
        XCTAssertEqual(
            route(
                "https://development-18fcf.web.app/c39f1e8b-cabb-44c9-822e-e0d7ee92a90d/474503d1-1adc-4268-88fe-2a797148f16d/list?c=03cc4ea0-9f77-4eb3-b47d-cacfe6ea8ada"
            ),
            OrgRoute("c39f1e8b-cabb-44c9-822e-e0d7ee92a90d",
                     .project(ProjectRoute("474503d1-1adc-4268-88fe-2a797148f16d",
                                           .task("03cc4ea0-9f77-4eb3-b47d-cacfe6ea8ada"))))
        )

        // project media
        XCTAssertEqual(
            route(
                "https://development-18fcf.web.app/c39f1e8b-cabb-44c9-822e-e0d7ee92a90d/474503d1-1adc-4268-88fe-2a797148f16d/media"
            ),
            OrgRoute("c39f1e8b-cabb-44c9-822e-e0d7ee92a90d",
                     .project(ProjectRoute("474503d1-1adc-4268-88fe-2a797148f16d", .media)))
        )
        XCTAssertEqual(
            route(
                "https://development-18fcf.web.app/c39f1e8b-cabb-44c9-822e-e0d7ee92a90d/474503d1-1adc-4268-88fe-2a797148f16d/media/c5441bd5-ab2f-460e-9868-87e90e842f5b"
            ),
            OrgRoute("c39f1e8b-cabb-44c9-822e-e0d7ee92a90d",
                     .project(ProjectRoute("474503d1-1adc-4268-88fe-2a797148f16d",
                                           .fullscreenMedia("c5441bd5-ab2f-460e-9868-87e90e842f5b"))))
        )
    }
}
