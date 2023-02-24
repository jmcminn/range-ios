import Foundation

/// Available pin types
enum PinType {
    case photo, task
}

/// Defines the options when creating a pin
enum PinTypeOption: Equatable {
    case pinType(PinType) // select a pin type
    case copyTask // select to copy a task

    var pinType: PinType {
        if case let .pinType(pinType) = self {
            return pinType
        } else {
            return .task
        }
    }
}

/// UI properties
extension PinTypeOption {
    var uiShortName: String {
        switch self {
        case .pinType(.photo): return String(localized: "Photo Pin")
        case .pinType(.task): return String(localized: "Task Pin")
        case .copyTask: return String(localized: "Copy Task")
        }
    }

    var uiLongName: String {
        switch self {
        case .pinType(.photo): return String(localized: "Photo Pin")
        case .pinType(.task): return String(localized: "Task Pin")
        case .copyTask: return String(localized: "Copy Task Pin")
        }
    }

    var uiDescription: String {
        switch self {
        case .pinType(.photo): return String(localized: "Document conditions and progress over time.")
        case .pinType(.task): return String(localized: "Assign work to people and monitor progress.")
        case .copyTask: return String(localized: "Copy data from an existing task.")
        }
    }

    var uiImageName: String {
        switch self {
        case .pinType(.photo): return "add_photo_pin"
        case .pinType(.task): return "add_task_pin"
        case .copyTask: return "add_task_pin"
        }
    }
}
