import Foundation

/// Available pin types
enum PinType {
    case photo, task, photoOrTask
}

/// Defines the options when creating a pin
enum PinTypeOption: String, Equatable, CaseIterable {
    case createPhoto
    case createTask
    case copyPin // select to copy a task

    var pinType: PinType {
        switch self {
        case .createPhoto: return .photo
        case .createTask: return .task
        case .copyPin: return .photoOrTask
        }
    }
}

/// UI properties
extension PinTypeOption {
    var uiShortName: String {
        switch self {
        case .createPhoto: return String(localized: "Photo Pin")
        case .createTask: return String(localized: "Task Pin")
        case .copyPin: return String(localized: "Copy Pin")
        }
    }

    var uiLongName: String {
        switch self {
        case .createPhoto: return String(localized: "Photo Pin")
        case .createTask: return String(localized: "Task Pin")
        case .copyPin: return String(localized: "Copy Existing Pin")
        }
    }

    var uiDescription: String {
        switch self {
        case .createPhoto: return String(localized: "Document conditions and progress over time.")
        case .createTask: return String(localized: "Assign work to people and monitor progress.")
        case .copyPin: return String(localized: "Copy data from an existing pin.")
        }
    }

    var uiImageName: String {
        switch self {
        case .createPhoto: return "add_photo_pin"
        case .createTask: return "add_task_pin"
        case .copyPin: return "copy_pin"
        }
    }
}
