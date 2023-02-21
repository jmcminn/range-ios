import Foundation
import QuickLook
import UIKit
import WebKit

class DocumentThumbnailGenerator {
    private unowned let mediaCache: MediaCache
    private unowned let containerView: UIView

    enum ThumbnailSource {
        // thumbnail generated using QuickLook, doesn't require the containerView
        case quickLook
        // thumbnail generated using WebKit, does require the containerView and returns proper
        // image only if the containerView is fully visible on screen
        case webKit
    }

    private var generator: WebViewImageGenerator?

    init(mediaCache: MediaCache, containerView: UIView) {
        self.mediaCache = mediaCache
        self.containerView = containerView
    }

    /// Generates jpeg thumbnail.1 for given (non-thumbnail) key of a document (not an image)
    func generateThumbnail(forKey key: MediaKey) async throws -> (image: UIImage, source: ThumbnailSource) {
        //
        let fileURL = try await mediaCache.getCachedFileURL(forKey: key)
        do {
            return try await (generateQLThumbnail(forFile: fileURL), .quickLook)
        } catch {
            // no QL thumb, fallback to web view based
            return try await (generateWebViewThumbnail(forFile: fileURL), .webKit)
        }
    }

    @MainActor
    private func generateQLThumbnail(forFile fileURL: URL) async throws -> UIImage {
        let thumbnailRequest = QLThumbnailGenerator.Request(
            fileAt: fileURL,
            size: CGSize(width: _thumbnail1Size, height: _thumbnail1Size),
            scale: UIScreen.main.scale,
            representationTypes: .thumbnail
        )
        let thumbnailRepresentation = try await QLThumbnailGenerator.shared
            .generateBestRepresentation(for: thumbnailRequest)
        return thumbnailRepresentation.uiImage
    }

    @MainActor
    private func generateWebViewThumbnail(forFile fileURL: URL) async throws -> UIImage {
        try await withUnsafeThrowingContinuation { continuation in
            let generator = WebViewImageGenerator(
                imageSize: CGSize(width: _thumbnail1Size, height: _thumbnail1Size),
                fileURL: fileURL
            )
            // the webview needs to be added to view hierarchy to render anything...
            containerView.addSubview(generator.webView)
            generator.webView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            generator.generate { [generator] image, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: image!)
                }
                generator.webView.removeFromSuperview()
            }
        } as UIImage
    }

    /// Wrap WKWebView loadFileURL to convert from the delegate based to a callback.
    /// This a run-once class. It get's all the parameters in the constructor and expects `generate` called once.
    fileprivate class WebViewImageGenerator: NSObject, WKNavigationDelegate {
        let webView: WKWebView
        private let fileURL: URL
        private var completion: ((UIImage?, Error?) -> Void)!
        private var navigation: WKNavigation?

        /// - Parameters:
        ///   - fileURL - the url of a local file to be converted to thumbnail
        init(imageSize: CGSize, fileURL: URL) {
            webView = WKWebView(frame: CGRect(origin: .zero, size: imageSize))
            self.fileURL = fileURL
            super.init()
            webView.navigationDelegate = self
        }

        func generate(completion: @escaping (UIImage?, Error?) -> Void) {
            self.completion = completion
            navigation = webView.loadFileURL(fileURL, allowingReadAccessTo: fileURL)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if self.navigation == navigation {
                // with no 0.1 seconds wait the screen is blank
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
                    self.completion(webView.asImage(), nil)
                }
            }
        }

        func webView(_: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            if self.navigation == navigation {
                completion(nil, error)
            }
        }
    }
}
