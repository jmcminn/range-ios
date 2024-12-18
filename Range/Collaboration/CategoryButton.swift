import UIKit

class CategoryButton: RangeButton {
    
    var category: Category? {
        didSet {
            updateButton()
        }
    }
    
    convenience init(primaryAction: UIAction? = nil) {
        var config = UIButton.Configuration.blackButton(imagePlacement: .leading, cornerRadius: 8)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = ._preferredFont(forTextStyle: .caption1, symbolicTraits: .traitBold)
            return outgoing
        }
        self.init(configuration: config, primaryAction: primaryAction)
    }
    
    private func updateButton() {
        if let category {
            setTitle(category.name, for: .normal)
            if let icon = category.icon?.imageResized(toFill: 30).withRenderingMode(.alwaysTemplate) {
                setImage(icon, for: .normal)
            }
        } else {
            setTitle("Unassigned", for: .normal)
            setImage(nil, for: .normal)
        }
    }
}
