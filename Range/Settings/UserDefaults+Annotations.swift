import Foundation
import UIKit

/// Functions for handling Annotations related UserDefaults (see the UserDefaults.swift file for the definition of the UserDefaultsConstants)
extension UserDefaults {
    static var lastPickedAnnotationColor: UIColor {
        get {
            if let colorHex = UserDefaults.standard
                .object(forKey: UserDefaultsConstants.lastPickedAnnotationColor.rawValue) as? String
            {
                return UIColor(hexString: colorHex)
            }
            return .Red_03
        }
        set {
            UserDefaults.standard.set(
                newValue.hexString,
                forKey: UserDefaultsConstants.lastPickedAnnotationColor.rawValue
            )
        }
    }

    static var lastPickedAnnotationLineThickness: Annotations.LineThickness {
        get {
            if let rawValue = UserDefaults.standard
                .object(forKey: UserDefaultsConstants.lastPickedAnnotationLineThickness.rawValue) as? String
            {
                return Annotations.LineThickness(rawValue: rawValue) ?? .medium
            }
            return .medium
        }
        set {
            UserDefaults.standard.setValue(
                newValue.rawValue,
                forKey: UserDefaultsConstants.lastPickedAnnotationLineThickness.rawValue
            )
        }
    }

    static var lastPickedAnnotationFontSize: Annotations.FontSize {
        get {
            if let rawValue = UserDefaults.standard
                .object(forKey: UserDefaultsConstants.lastPickedAnnotationFontSize.rawValue) as? String
            {
                return Annotations.FontSize(rawValue: rawValue) ?? .medium
            }
            return .medium
        }
        set {
            UserDefaults.standard.setValue(
                newValue.rawValue,
                forKey: UserDefaultsConstants.lastPickedAnnotationFontSize.rawValue
            )
        }
    }

    /// return at most last 10 recent annotation texts. The most recent text is at the end of the array
    static func recentAnnotationTexts() -> [String] {
        (UserDefaults.standard.array(forKey: UserDefaultsConstants.recentAnnotationTexts.rawValue) as? [[String]])?
            .compactMap { recentTextEntry in
                recentTextEntry[1] // defaults store [id, text], we need the text only
            } ?? []
    }

    /// adds given text annotations to recent annotation texts (the order of input matters, the elements with higher
    /// indices are treated as more recent)
    /// If element with given id exist in recent annotation texts it will be reinserted at the end (so it's "more recent")
    /// only 10 most recent items are kept
    static func addRecentAnnotationTexts(_ annotations: [TextAnnotation]) {
        var entries: [[String]] = (UserDefaults.standard.array(
            forKey: UserDefaultsConstants.recentAnnotationTexts.rawValue
        ) as? [[String]]) ?? []
        // Remove existing entries with ids matching the updated annotations
        entries.removeAll { existingEntry in
            let existingEntryId = existingEntry[0]
            return annotations.contains { $0.id == existingEntryId }
        }
        // Add new/updated annotations to the end of the array (to make it most recent), while doing
        // it also remove any text duplicates.
        // Removing text duplicates is done after removing items with same ids, to deduplicate first by id
        // and then by text. It also makes sure that text duplicates from input annotations are not
        // stored
        for annotation in annotations {
            entries.removeAll { existingEntry in
                let existingEntryText = existingEntry[1]
                return existingEntryText == annotation.text
            }
            entries.append([annotation.id, annotation.text])
        }
        // keep last 10 at most
        if entries.count > 10 {
            entries.removeFirst(entries.count - 10)
        }
        // store in user defaults for given project key
        UserDefaults.standard.set(
            entries,
            forKey: UserDefaultsConstants.recentAnnotationTexts.rawValue
        )
    }

    /// Get all added/updated text annotations comparing the Annotations before and after the change
    /// The result of this function can be passed to `addRecentAnnotationTexts`
    static func getUpdatedTextAnnotations(_ oldAnnotations: Annotations?,
                                          _ newAnnotations: Annotations?) -> [TextAnnotation]
    {
        guard let newAnnotations = newAnnotations else { return [] }
        let newTextAnnotations = newAnnotations.getTextAnnotations()

        guard let oldAnnotations = oldAnnotations else { // everything is new
            return newTextAnnotations
        }
        let oldTextAnnotations = oldAnnotations.getTextAnnotations()

        return newTextAnnotations.filter { new in
            // included if it's new, or has updated text
            if let old = oldTextAnnotations.first(where: { $0.id == new.id }) {
                return old.text != new.text
            }
            return true
        }
    }
}
