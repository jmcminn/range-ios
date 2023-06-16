import FirebaseStorage
import Foundation
import OrderedCollections
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

private class CanvasFileLoadRequest: Hashable, Equatable {
    /// the path in the cloud storage from which the file needs to be downloaded
    let storagePath: String
    /// the folder to put the downloaded file in
    let localDirURL: URL
    /// the file to put the downloaded file in
    let localFileURL: URL
    /// callback to be called once the download is complete
    var callback: ((Error?) -> Void)?

    init(
        forSource source: CanvasSource,
        projectId: String,
        localStorageDirectoryURL: URL
    ) {
        guard case let .pdf(pdfSource) = source.data else {
            fatalError("reloadPdfPage called when canvas source is not a PDF")
        }

        storagePath = "projects/\(projectId)/canvasSources/\(source.id)"

        // use storage version if present to load/store the file locally, so when the version
        // gets updated the new file will be downloaded
        let localFileName: String
        if let storageVersion = pdfSource.mainStorageVersion() {
            localFileName = "\(storageVersion).pdf"
        } else {
            localFileName = "_.pdf"
        }
        // The directory for this canvas files. We always want just the latest file (the storage
        // version is part of the file name). Each canvas has a separate directory so it's easy
        // to remove it when downloading new version of canvas file (the older version is not needed)
        localDirURL = localStorageDirectoryURL.appendingPathComponent(storagePath)
        localFileURL = localDirURL.appendingPathComponent(localFileName)
    }

    /// Requests are equal if they point to the same storage path (meaning it's the same file that will be stored in the same local location)
    static func == (lhs: CanvasFileLoadRequest, rhs: CanvasFileLoadRequest) -> Bool {
        lhs.storagePath == rhs.storagePath
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(storagePath)
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

    /// Background serial queue to perform operations
    private let operationQueue = DispatchQueue(label: "canvas-file-loader-operation-queue")
    /// The queue of pending download requests
    private var pendingRequests = OrderedSet<CanvasFileLoadRequest>()
    /// Only one request can be performed at a time.
    /// This is indicating if a request is currently being performed.
    /// To be set/get on the `operationQueue` only
    var performingRequest: Bool = false

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

    /// Append the request to download given source to the end of the downloads queue
    /// - Parameters:
    ///   - request:
    ///   - priority:  if `true` the file will be downloaded as the next item, otherwise will be inserted to the end of downloads queue
    private func addRequest(_ request: CanvasFileLoadRequest, priority: Bool = false) {
        operationQueue.async { [weak self] in
            if priority {
                self?.pendingRequests.insert(request, at: 0)
            } else {
                self?.pendingRequests.append(request)
            }
            self?.maybePerformRequest()
        }
    }

    /// Perform next request if there's anything in pendingRequests and if no request is being performed now
    /// To be invoked on the `operationQueue`
    private func maybePerformRequest() {
        guard !performingRequest else { return }
        guard let request = pendingRequests.first else { return }
        pendingRequests.removeFirst()
        performRequest(request) { [weak self] error in
            if let requestCallback = request.callback {
                DispatchQueue.main.async {
                    requestCallback(error)
                }
            }
            self?.operationQueue.async {
                self?.performingRequest = false
                self?.maybePerformRequest()
            }
        }
    }

    private func performRequest(_ request: CanvasFileLoadRequest, completion: @escaping (Error?) -> Void) {
        if fileManager.fileExists(atPath: request.localFileURL.path) {
            // file exists, nothing to do
            completion(nil)
            return
        } else {
            // no file locally, but maybe the canvas directory is there => remove it as it may contain
            // an old version of pdf
            if fileManager.fileExists(atPath: request.localDirURL.path) {
                Logger.storage.debug("Removing old canvas from local dir: \(request.localDirURL)")
                do {
                    try fileManager.removeItem(at: request.localDirURL)
                } catch {
                    // do not fail the operation if old files failed to remove
                    Logger.storage.debug("Removing old canvas from local dir: \(request.localDirURL) failed: \(error)")
                }
            }
        }
        // download from Storage
        Logger.storage.debug("Downloading canvas from Storage: \(request.storagePath)")
        storage.reference(withPath: request.storagePath).write(toFile: request.localFileURL) { _, error in
            if let error = error {
                completion(error)
                return
            }
            // exclude from backup
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            var localFileURL = request.localFileURL
            do {
                try localFileURL.setResourceValues(resourceValues)
            } catch {
                Logger.storage.debug("Failed to exclude from backup: \(localFileURL)")
            }
            completion(nil)
        }
    }

    /// Schedule download of given canvas source pdf.
    /// It will be only downloaded if it's not downloaded yet
    /// No callback is provided as this function is now only used to prefetch the PDF pages, when the PDF page is actually need
    /// call the `loadPDFPage` function.
    /// It's safe to call this function and `loadPDFPage` function multiple times for the same canvas source. The requests are queued (and deduplicated)
    /// so the file for given storage version is only downloaded once.
    func downloadPDF(forSource source: CanvasSource, projectId: String) {
        addRequest(
            CanvasFileLoadRequest(
                forSource: source,
                projectId: projectId,
                localStorageDirectoryURL: localStorageDirectoryURL
            ),
            priority: false
        )
    }

    @MainActor
    /// Loads PDFPage for given canvas source. If the file exists locally it is used, otherwise it's downloaded from the Storage.
    func loadPDFPage(forSource source: CanvasSource, projectId: String) async throws -> PDFPage {
        let request = CanvasFileLoadRequest(
            forSource: source,
            projectId: projectId,
            localStorageDirectoryURL: localStorageDirectoryURL
        )
        try await withUnsafeThrowingContinuation { continuation in
            request.callback = { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
            self.addRequest(request, priority: true)
        } as Void

        // use downloaded file
        Logger.storage.debug("Loading canvas from local file: \(request.localFileURL)")
        return try loadPDFPage(fromLocalFile: request.localFileURL, pageNumber: 0)
    }

    /// Loads PDFPage with given number (zero based) from given local file
    private func loadPDFPage(fromLocalFile localFileURL: URL, pageNumber: Int) throws -> PDFPage {
        guard let document = PDFDocument(url: localFileURL) else {
            throw CanvasFileLoaderError.pdfDocumentLoadFailed
        }
        guard let page = document.page(at: pageNumber) else {
            throw CanvasFileLoaderError.pdfPageLoadFailed(pageNumber)
        }
        return page
    }
}
