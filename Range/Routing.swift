import Foundation

// Supported App routes - routes that can be directly open in the app from universal links or push notifications

/// Main entry route for organization
struct OrgRoute: Equatable {
    enum Route: Equatable {
        case projects
        case project(_: ProjectRoute)
    }

    var organizationId: String
    var route: Route

    init(_ id: String, _ route: Route) {
        organizationId = id
        self.route = route
    }
}

/// Subroute for organization project
struct ProjectRoute: Equatable {
    enum Route: Equatable {
        // project is showing a canvas with a possibly selected collaboration (if collaborationId != nil)
        // canvasId is optional so this route can be used with collaborationId only (the canvas will
        // be selected based on the collaborationId)
        // In case canvasId and collaborationId are both nil the project shows the default view.
        // In case canvasId and collaborationId are both not nil, the collaborationId is used.
        // Warning: instead of using the nil canvasId, the collaborationId-only route could be supported
        // by the .task route, but we wanted to keep the difference between canvas and task routes
        // in case we ever want to produce a web-app compatible urls from these routes (then task
        // is different than collaboration, and we don't want to rename the task route to "collaboration"
        // as then it doesn't fit the case of showing a task from task list)
        case canvas(_ canvasId: String?, collaborationId: String?)
        // a route for newly created project - may present some welcome card, etc.
        case welcome
        // "Task List" screen for a project (the default/last canvas is used)
        case tasks
        // project task is shown - this is similar to canvas case, but no canvas is given as in web
        // this comes from tasks (list) view. In iOS app selecting task from task list opens it in the canvas view
        case task(_ collaborationId: String)
        // "All Media" screen for a project
        case media
        // fullscreen media view displayed on top of "All Media"
        case fullscreenMedia(_ uploadId: String)
    }

    var projectId: String
    var route: Route

    init(_ id: String, _ route: Route) {
        projectId = id
        self.route = route
    }
}

/// Returns true if given string is a valid UUID
private func validUUIDString(_ uuidString: String) -> Bool {
    UUID(uuidString: uuidString) != nil
}

/// Returns a supported OrgRoute for given url
/// Not all urls from web app are supported by the iOS app, see the OrgRoute, ProjectRoute and RoutingTest for details
func routeForURL(_ url: URL) -> OrgRoute? {
    guard let components = NSURLComponents(url: url, resolvingAgainstBaseURL: true),
          let path = components.path?.split(separator: "/").map({ String($0) }),
          !path.isEmpty
    else { return nil }

    let orgId = path[0]
    // the first element must be organization id
    guard validUUIDString(orgId) else { return nil }

    let collaborationId: String? = components.queryItems?.first(where: { $0.name == "c" })?.value

    if path.count >= 3, validUUIDString(path[1]) {
        let projectId = path[1]

        if validUUIDString(path[2]) {
            // it's a canvas id, so a project canvas route
            let canvasId = path[2]
            return OrgRoute(orgId, .project(
                ProjectRoute(projectId, .canvas(canvasId, collaborationId: collaborationId))
            ))
        } else if path[2] == "list" {
            if let collaborationId {
                return OrgRoute(orgId, .project(ProjectRoute(projectId, .task(collaborationId))))
            } else {
                return OrgRoute(orgId, .project(ProjectRoute(projectId, .tasks)))
            }
        } else if path[2] == "media" {
            if path.count >= 4, validUUIDString(path[3]) {
                let uploadId = path[3]
                return OrgRoute(orgId, .project(ProjectRoute(projectId, .fullscreenMedia(uploadId))))
            } else {
                return OrgRoute(orgId, .project(ProjectRoute(projectId, .media)))
            }
        }
    } else {
        // <orgId>/projects (or any non <orgId>/<projectId> path)
        return OrgRoute(orgId, .projects)
    }
    return nil
}
