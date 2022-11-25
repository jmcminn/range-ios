import FirebaseStorage
import FirebaseStorageSwift
import Foundation
import OSLog
import PDFKit

// possible errors for CanvasFileLoader
enum CanvasFileLoaderError: Error {
    case pdfDocumentLoadFailed
    case pdfPageLoadFailed(Int)
}

// Error extension to provide localized descriptions of errors
extension CanvasFileLoaderError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .pdfDocumentLoadFailed:
            return "Couldn't load the PDF document"
        case let .pdfPageLoadFailed(page):
            return "Couldn't load the PDF page number \(page)"
        }
    }
}

/// Loads canvas pdf files.
/// It downloads the files from Firebase Storage and keeps in the local filesystem, so a file is only downloaded once.
class CanvasFileLoader {
    /// Firebase storage for canvas pdfs
    private let storage = Storage.storage()
    private let fileManager = FileManager.default
    /// Root url for local pdf files. Inside this directory there's the same structure as in the Firebase Storage
    private let localStorageDirectoryURL: URL

    /// Throws if it cannot access the filesystem
    init() throws {
        let applicationDirectory = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        localStorageDirectoryURL = applicationDirectory.appendingPathComponent("pdfs")
    }

    @MainActor
    /// Loads PDFPage for given canvas. If the file exists locally it is used, otherwise it's downloaded from the Storage.
    func loadPDFPage(forCanvas pdfCanvas: PDFCanvas, projectId: String) async throws -> PDFPage {
        let path = "projects/\(projectId)/canvasCollections/\(pdfCanvas.canvasCollectionId)"
        var localPdfFileURL = localStorageDirectoryURL.appendingPathComponent("\(path).pdf")

        // try loading from local file first if already downloaded
        if fileManager.fileExists(atPath: localPdfFileURL.path) {
            Logger.storage.debug("Loading canvas from local file: \(path)")
            do {
                return try loadPDFPage(fromLocalFile: localPdfFileURL, pageNumber: pdfCanvas.pageNumber)
            } catch {
                // cannot load, try download again
                Logger.storage.error("Loading canvas from local file \(path) failed: \(error.localizedDescription)")
            }
        }

        // download from Storage
        Logger.storage.debug("Downloading canvas from Storage: \(path)")
        _ = try await storage.reference(withPath: path).writeAsync(toFile: localPdfFileURL)

        // exclude from backup
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        do {
            try localPdfFileURL.setResourceValues(resourceValues)
        } catch {
            Logger.storage.debug("Failed to exclude from backup: \(path)")
        }

        // use downloaded file
        Logger.storage.debug("Loading canvas from local file: \(path)")
        return try loadPDFPage(fromLocalFile: localPdfFileURL, pageNumber: pdfCanvas.pageNumber)
    }

    /// Loads PDFPage with given number (zero based) from given local file
    func loadPDFPage(fromLocalFile localFileURL: URL, pageNumber: Int) throws -> PDFPage {
        guard let document = PDFDocument(url: localFileURL) else {
            throw CanvasFileLoaderError.pdfDocumentLoadFailed
        }
        guard let page = document.page(at: pageNumber) else {
            throw CanvasFileLoaderError.pdfPageLoadFailed(pageNumber)
        }
        return page
    }
}
