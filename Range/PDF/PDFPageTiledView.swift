//
//  PDFPageTiledView.swift
//  Range
//
//  Created by raho on 18/03/2022.
//

import PDFKit
import QuartzCore
import UIKit

/// A UIView using CATiledLayer for displaying PDFPage with level of detail depending on the zoom level.
class PDFPageTiledView: UIView {
    
    
    // returns layer property as CATiledLayer
    var tiledLayer: CATiledLayer {
        return self.layer as! CATiledLayer
    }
    
    /*
     Force contentScaleFactor of 1, even on retina displays For the CATiledLayer
     to handle the interaction between CATiledLayer and high resolution screens, we need to manually set the
     tiling view's contentScaleFactor to 1.0. (If we omitted this, it would be 2.0 on high resolution screens,
     which would cause the CATiledLayer to ask us for tiles of the wrong scales.)
     */
    override var contentScaleFactor: CGFloat {
        didSet {
            super.contentScaleFactor = 1
        }
    }
    
    /// Page of the PDF to be tiled
    private let pdfPage: PDFPage
    
    /// Current PDF scale
    private let scale: CGFloat
    
    /// Initializes a fresh tiled view
    ///
    /// - parameter frame:   desired frame of the tiled view
    /// - parameter scale:   scale factor
    /// - parameter pdfPage: page representation
    init(frame: CGRect, scale: CGFloat, pdfPage: PDFPage) {
        self.scale = scale
        self.pdfPage = pdfPage
        super.init(frame: frame)
        
        // levelsOfDetail and levelsOfDetailBias determine how many different rendering levels there are
        tiledLayer.levelsOfDetail = 8
        tiledLayer.levelsOfDetailBias = 7
        tiledLayer.tileSize = CGSize(width: 1024, height: 1024)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override class var layerClass : AnyClass {
        return CATiledLayer.self
    }
    
    // Draw the CGPDFPage into the layer at the correct scale.
    override func draw(_ layer: CALayer, in con: CGContext) {
        con.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        con.fill(layer.bounds)
        
        con.saveGState()
        
        // PDF has (0,0) in the bottom left
        con.translateBy(x: 0, y: layer.bounds.height)
        con.scaleBy(x: 1, y: -1)
        
        // Scale the context so that the PDF page is rendered at the correct size for the zoom level.
        con.scaleBy(x: scale, y: scale)
        pdfPage.transform(con, for: .mediaBox)
        pdfPage.draw(with: .mediaBox, to: con)
        con.restoreGState()
    }
    
    // Stops drawLayer
    deinit {
        layer.contents = nil
        layer.delegate = nil
        layer.removeFromSuperlayer()
    }
    
}

