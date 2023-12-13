import Foundation
import OSLog
import UIKit

/// Functions for handling Annotations related UserDefaults (see the UserDefaults.swift file for the definition of the UserDefaultsConstants)
extension UserDefaults {
    static var lastPickedAnnotationColor: UIColor {
        get {
            if let colorHex = UserDefaults.standard
                .object(forKey: UserDefaultsConstants.lastPickedAnnotationColor.rawValue) as? String
            {
                return UIColor(hexString: colorHex) ?? .Red_03
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

    /// return at most last 10 recent text annotations. The most recent annotation is at the end of the array
    /// The annotations stored here are not scaled!!
    static func recentTextAnnotations() -> [TextAnnotation] {
        /// the annotations are stored as an array of annotations encoded as JSON strings
        guard let textAnnotationStrings = (UserDefaults.standard
            .array(forKey: UserDefaultsConstants.recentAnnotations.rawValue) as? [String])
        else {
            return []
        }
        let jsonDecoder = JSONDecoder()
        return textAnnotationStrings.compactMap { annotationString in
            guard let annotationData = annotationString.data(using: .utf8),
                  let annotation = try? jsonDecoder.decode(TextAnnotation.self, from: annotationData)
            else {
                Logger.settings.error("Failed to decode recent annotation: \(annotationString)")
                return nil
            }
            return annotation
        }
    }

    /// Adds given text annotation to recent annotations
    /// If element with given id exist in recent annotations it will be reinserted at the end (so it's "more recent")
    /// Only 10 most recent items are kept
    /// The items in the recent annotations list are deduplicated by text/fontSize/color
    /// - Parameters:
    ///   - annotation: the annotation to save
    ///   - annotationsGeometry: we need the annotations scale to unscale the annotation font size
    static func addRecentTextAnnotation(_ annotation: TextAnnotation, _ annotationsGeometry: AnnotationsGeometry) {
        let fontSize = annotation.fontSize / annotationsGeometry.scale

        // we need to store a copy, so we don't change the original annotation
        let annotation = TextAnnotation(
            id: annotation.id,
            text: annotation.text,
            position: .zero,
            fontSize: fontSize,
            color: annotation.color
        )

        var entries = recentTextAnnotations()
        // Remove existing entry with id matching the updated annotation
        entries.removeAll { entry in
            annotation.id == entry.id
        }
        // Remove any annotations with duplicated content.
        // Text annotation is a duplicate from this point of view if it has the same text, font size and color.
        // Removing the duplicates is done after removing items with same id, to deduplicate first by id
        // and then by content.
        entries.removeAll { entry in
            entry.text == annotation.text && entry.fontSize == annotation.fontSize
                && entry.hexColor == annotation.hexColor
        }
        // Add updated annotation to the end of the array (to make it most recent),
        entries.append(annotation)
        // keep last 10 at most
        if entries.count > 10 {
            entries.removeFirst(entries.count - 10)
        }
        let jsonEncoder = JSONEncoder()
        // convert TextAnnotation(s) to json strings
        let entriesStrings: [String] = entries.compactMap { entry in
            guard let entryData = try? jsonEncoder.encode(entry),
                  let entryString = String(data: entryData, encoding: .utf8)
            else {
                Logger.settings.error("Failed to encode recent annotation: \(entry)")
                return nil
            }
            return entryString
        }
        // store in user defaults for given project key
        UserDefaults.standard.set(
            entriesStrings,
            forKey: UserDefaultsConstants.recentAnnotations.rawValue
        )
    }
}
