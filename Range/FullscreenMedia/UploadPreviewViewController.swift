import Foundation
import OSLog
import QuickLook
import UIKit
import WebKit

/// For non-image Uploads it displays the type and size of the upload. It also displays the "Tap to download" button.
/// If the thumbnail.1 for given document is in media cache it will display it immediatelly. If it's not there but the upload is small
/// (see `maxAutoDownloadSize`) (or the document is already in cache) then it'll download the file and generate the thumbnail.1 jpeg
/// and store in media cache (and automatically display).
/// If file is bigger then the download and preview generation is manually triggered by user tapping the button.
class UploadPreviewViewController: UIViewController {
    /// The file will be automatically downloaded to generate the preview if its size is <= maxAutoDownloadSize
    private static var maxAutoDownloadSize = 200 * 1024

    private unowned let projectModel: ProjectModel
    private unowned let mediaCache: MediaCache
    private let boxView = UIView()
    private let fileTypeLabel = UILabel()
    private let fileSizeLabel = UILabel()
    private var downloadButton: UIButton!
    private let imageView = UIImageView()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    var upload: Upload? {
        didSet {
            uploadUpdated()
        }
    }

    private var mediaKey: MediaKey? {
        guard let upload = upload else { return nil }
        return MediaKey(projectId: projectModel.projectId, upload: upload)
    }

    private var thumbnailKey: MediaKey? {
        guard let upload = upload else { return nil }
        return MediaKey(projectId: projectModel.projectId, uploadId: upload.id, fileType: .jpeg, thumbnailNumber: 1)
    }

    /// notifies when height to width ratio was calculated
    public var onAspectRatioLoaded: ((Double) -> Void)?

    /// By default it's disabled. For web kit generated thumbnails to work properly the whole web view must be on screen
    /// which is not easy to control (for example when preview is rendered in the table view which user scrolls)
    var cacheWebKitGeneratedThumbnails: Bool = false

    init(projectModel: ProjectModel, mediaCache: MediaCache) {
        self.projectModel = projectModel
        self.mediaCache = mediaCache
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .dynamic(.Neutral_10)
        view.clipsToBounds = true

        setupBoxView()
        view.addSubview(boxView)

        // assume the button has height = 32 and layout box + button centered that way
        // so we have 110 + 16 + 32 = 158, half of it = 79
        boxView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.width.equalTo(90)
            make.height.equalTo(110)
            make.top.equalTo(view.snp.centerY).offset(-79)
        }

        setupDownloadButton()
        view.addSubview(downloadButton!)
        downloadButton!.snp.makeConstraints { make in
            make.top.equalTo(boxView.snp.bottom).offset(16)
            make.centerX.equalToSuperview()
        }

        setupImageView()
        view.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        activityIndicator.color = .dynamic(.Neutral_04)
        view.addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints { make in
            make.center.equalTo(downloadButton)
        }

        updateColors()

        // reset the UI
        uploadUpdated()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateColors()
        }
    }

    private func updateColors() {
        boxView.layer.borderColor = chooseColor(.Neutral_07).cgColor
    }

    private func setupBoxView() {
        boxView.layer.cornerRadius = 10
        boxView.layer.borderWidth = 1
        boxView.backgroundColor = .dynamic(.Neutral_09)

        fileTypeLabel.textColor = .dynamic(.Neutral_05)
        fileTypeLabel.adjustsFontForContentSizeCategory = true
        fileTypeLabel.adjustsFontSizeToFitWidth = true
        fileTypeLabel.textAlignment = .center
        fileTypeLabel.font = ._preferredFont(forTextStyle: .title3, symbolicTraits: .traitBold)
        boxView.addSubview(fileTypeLabel)
        fileTypeLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview().offset(-4)
            make.leading.trailing.equalToSuperview().inset(6)
        }

        fileSizeLabel.font = ._preferredFont(forTextStyle: .footnote, symbolicTraits: .traitBold)
        fileSizeLabel.textColor = .dynamic(.Neutral_05)
        fileSizeLabel.adjustsFontForContentSizeCategory = true
        fileSizeLabel.adjustsFontSizeToFitWidth = true
        fileSizeLabel.textAlignment = .center
        boxView.addSubview(fileSizeLabel)
        fileSizeLabel.snp.makeConstraints { make in
            make.top.equalTo(fileTypeLabel.snp.bottom).offset(6)
            make.leading.trailing.equalToSuperview().inset(6)
        }
    }

    private func setupDownloadButton() {
        var config = UIButton.Configuration.blackButton(cornerRadius: 100)
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16)
        downloadButton = UIButton(
            configuration: config,
            primaryAction: UIAction(title: String(localized: "Tap to download"), handler: { [weak self] _ in
                self?.generateThumbnail()
            })
        )
    }

    private func setupImageView() {
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.isHidden = true
    }

    private func uploadUpdated() {
        // reset the UI
        setActivityIndicator(hidden: true)
        setImageView(hidden: true)
        if let upload = upload {
            fileTypeLabel.text = ".\(upload.fileType.rawValue.lowercased())"
            if let fileSize = upload.fileSize {
                fileSizeLabel.text = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
            } else {
                fileSizeLabel.text = nil
            }
            showPreviewIfCachedOrSmall()
        } else {
            fileTypeLabel.text = nil
            fileSizeLabel.text = nil
        }
    }

    private func showPreviewIfCachedOrSmall() {
        if let thumbnailKey = thumbnailKey, mediaCache.hasFile(forKey: thumbnailKey) {
            // The thumbnail is already in cache, just show it
            setActivityIndicator(hidden: false)
            let imageDataProvider = mediaCache.imageProvider(forKey: thumbnailKey)
            imageView.kf.setImage(with: imageDataProvider, options: imageDataProvider.options) { [weak self] result in
                // show image and hide
                if case let .success(imageResult) = result {
                    self?.setActivityIndicator(hidden: true)
                    self?.setImageView(hidden: false)
                    self?.onAspectRatioLoaded?(imageResult.image.size.height / imageResult.image.size.width)
                }
            }
        } else if let upload = upload, let uploadSize = upload.fileSize,
                  uploadSize < UploadPreviewViewController.maxAutoDownloadSize
        {
            // The thumbnail is not in cache yet but the document is small so download
            // it and generate thumbnail automatically
            generateThumbnail()
        } else if let mediaKey = mediaKey, mediaCache.hasFile(forKey: mediaKey) {
            // the upload document is already in the cache, generate the thumbnail no matter what size it is
            generateThumbnail()
        }
    }

    private func setActivityIndicator(hidden activityIndicatorHidden: Bool) {
        downloadButton.isHidden = !activityIndicatorHidden
        activityIndicator.isHidden = activityIndicatorHidden
        if activityIndicatorHidden {
            activityIndicator.stopAnimating()
        } else {
            activityIndicator.startAnimating()
        }
    }

    /// hide the UI for file type and download and show the image view if hidden == `false`
    private func setImageView(hidden imageViewHidden: Bool) {
        imageView.isHidden = imageViewHidden
        boxView.isHidden = !imageViewHidden
        downloadButton.isHidden = !imageViewHidden
    }

    private func generateThumbnail() {
        guard let mediaKey = mediaKey, let thumbnailKey = thumbnailKey else { return }
        // it is safe to remove the webView from view when generating thumbnail if we decide
        // it's safe to cache the webkit generated thumbnails (meaning they will be produced correctly)
        // in this case the resulting thumbnail image will be shown and there's no point
        // in keeping the web view in view hierarchy
        let generator = DocumentThumbnailGenerator(
            mediaCache: mediaCache,
            containerView: view,
            removeWebViewFromContainerViewWhenDone: cacheWebKitGeneratedThumbnails
        )
        setActivityIndicator(hidden: false)
        Task {
            do {
                let (image, source) = try await generator.generateThumbnail(forKey: mediaKey)
                let imageHeightToWidth = image.size.height / image.size.width
                // try to cache it
                if source == .quickLook || cacheWebKitGeneratedThumbnails {
                    do {
                        try projectModel.mainRealm.write {
                            upload?.imageHeightToWidth = imageHeightToWidth
                        }
                        let data = try image.jpegData(compressionQuality: 0.9).or(error: "Cannot get data for image")
                        try await mediaCache.store(data, forKey: thumbnailKey)
                    } catch {
                        // ignore caching errors
                    }
                }
                self.imageView.image = image
                self.setActivityIndicator(hidden: true)
                self.setImageView(hidden: false)
                self.onAspectRatioLoaded?(imageHeightToWidth)
            } catch {
                let key = mediaKey
                Logger.ui.debug("Couldn't generate thumbnail for \(key, privacy: .public)")
                ToastWindow.shared.showError(text: "Failed to generate the preview")
            }
        }
    }
}
