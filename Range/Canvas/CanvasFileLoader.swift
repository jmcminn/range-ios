import FirebaseStorage
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
        guard let canvasCollection = pdfCanvas.collection.first else {
            throw ModelError.canvasCollectionNotFound
        }
        let storagePath = "projects/\(projectId)/canvasCollections/\(canvasCollection.id)"
        // use storage version if present to load/store the file locally, so when the version
        // gets updated the new file will be downloaded
        let localFileName = canvasCollection.storageVersion != nil
            ? "\(canvasCollection.storageVersion!).pdf"
            : "_.pdf"
        // The directory for this canvas files. We always want just the latest file (the storage
        // version is part of the file name). Each canvas has a separate directory so it's easy
        // to remove it when downloading new version of canvas file (the older version is not needed)
        let localPdfDirURL = localStorageDirectoryURL.appendingPathComponent(storagePath)
        var localPdfFileURL = localPdfDirURL.appendingPathComponent(localFileName)

        // try loading from local file first if already downloaded
        if fileManager.fileExists(atPath: localPdfFileURL.path) {
            Logger.storage.debug("Loading canvas from local file: \(localPdfFileURL)")
            do {
                return try loadPDFPage(fromLocalFile: localPdfFileURL, pageNumber: pdfCanvas.pageNumber)
            } catch {
                // cannot load, try download again
                Logger.storage
                    .error("Loading canvas from local file \(localPdfFileURL) failed: \(error.localizedDescription)")
            }
        } else {
            // no file locally, but maybe the canvas directory is there => remove it as it may contain
            // an old version of pdf
            if fileManager.fileExists(atPath: localPdfDirURL.path) {
                Logger.storage.debug("Removing old canvas from local dir: \(localPdfDirURL)")
                do {
                    try fileManager.removeItem(at: localPdfDirURL)
                } catch {
                    // do not fail the operation if old files failed to remove
                    Logger.storage.debug("Removing old canvas from local dir: \(localPdfDirURL) failed: \(error)")
                }
            }
        }

        // download from Storage
        Logger.storage.debug("Downloading canvas from Storage: \(storagePath)")
        _ = try await storage.reference(withPath: storagePath).writeAsync(toFile: localPdfFileURL)

        // exclude from backup
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        do {
            try localPdfFileURL.setResourceValues(resourceValues)
        } catch {
            Logger.storage.debug("Failed to exclude from backup: \(localPdfFileURL)")
        }

        // use downloaded file
        Logger.storage.debug("Loading canvas from local file: \(localPdfFileURL)")
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
