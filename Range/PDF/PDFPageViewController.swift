//
//  PDFPageViewController.swift
//  Range
//
//  Created by raho on 18/03/2022.
//

import PDFKit
import Stevia
import UIKit

class PDFPageViewController: UIViewController {
    
    let pdfPage: PDFPage

    init(pdfPage: PDFPage) {
        self.pdfPage = pdfPage
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // we need some initial frame to setup the PDF
        let pdfView = PDFPageScrollView(frame: view.bounds, pdfPage: pdfPage, autoCenter: true)
        view.sv(pdfView)
        pdfView.fillContainer().centerInContainer()
    }
    
}
