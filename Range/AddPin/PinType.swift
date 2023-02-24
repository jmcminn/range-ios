import Foundation

/// Available pin types
enum PinType {
    case photo, task
}

/// Defines the options when creating a pin
enum PinTypeOption: String, Equatable, CaseIterable {
    case createPhoto
    case createTask
    case copyTask // select to copy a task

    var pinType: PinType {
        switch self {
        case .createPhoto: return .photo
        case .createTask: return .task
        case .copyTask: return .task
        }
    }
}

/// UI properties
extension PinTypeOption {
    var uiShortName: String {
        switch self {
        case .createPhoto: return String(localized: "Photo Pin")
        case .createTask: return String(localized: "Task Pin")
        case .copyTask: return String(localized: "Copy Task")
        }
    }

    var uiLongName: String {
        switch self {
        case .createPhoto: return String(localized: "Photo Pin")
        case .createTask: return String(localized: "Task Pin")
        case .copyTask: return String(localized: "Copy Task Pin")
        }
    }

    var uiDescription: String {
        switch self {
        case .createPhoto: return String(localized: "Document conditions and progress over time.")
        case .createTask: return String(localized: "Assign work to people and monitor progress.")
        case .copyTask: return String(localized: "Copy data from an existing task.")
        }
    }

    var uiImageName: String {
        switch self {
        case .createPhoto: return "add_photo_pin"
        case .createTask: return "add_task_pin"
        case .copyTask: return "add_task_pin"
        }
    }
}
