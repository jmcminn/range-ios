//
//  PDFSize.swift
//  Range
//
//  Created by raho on 25/03/2022.
//

import Foundation
import PDFKit

extension PDFPage {
    func sizeInMeters(forScale scale: Double) -> CGSize {
        let pageBounds = bounds(for: .mediaBox)
        let point2Inch = 1/72.0
        let inch2Meter = 0.0254
        let widthInMeters = Double(pageBounds.width) * point2Inch * inch2Meter / scale
        let heightInMeters = Double(pageBounds.height) * point2Inch * inch2Meter / scale
        return CGSize(width: widthInMeters, height: heightInMeters)
    }
}
