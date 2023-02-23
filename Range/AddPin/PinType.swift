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

    var uiName: String {
        switch self {
        case let .pinType(pinType):
            switch pinType {
            case .photo:
                return String(localized: "Photo Pin")
            case .task:
                return String(localized: "Task Pin")
            }
        case .copyTask:
            return String(localized: "Copy Task")
        }
    }
}
