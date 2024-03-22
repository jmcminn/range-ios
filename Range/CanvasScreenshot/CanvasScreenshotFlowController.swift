import Foundation
import SwiftUI
import UIKit

/// Manages the flow of taking a screenshot of current canvas and adding it to given collaboration
class CanvasScreenshotFlowController {
    let geometryId: String
    let model: ProjectModel
    let localFiles: LocalFiles
    let canvasContainer: CanvasContainerViewController

    private var selectionViewController: CanvasScreenshotSelectionViewController?

    /// called when the flow finishes
    var onStop: (() -> Void)?

    init?(
        collaboration: Collaboration,
        model: ProjectModel,
        localFiles: LocalFiles,
        canvasContainer: CanvasContainerViewController
    ) {
        guard !collaboration.isInvalidated,
              let geometryId = collaboration.feature.first?.geometry.first?.id else { return nil }
        self.geometryId = geometryId
        self.model = model
        self.localFiles = localFiles
        self.canvasContainer = canvasContainer
    }

    /// Show the UI for canvas screenshot
    func start() {
        selectionViewController = CanvasScreenshotSelectionViewController()
        selectionViewController?.onCancel = { [weak self] in
            self?.selectionViewController?.view.removeFromSuperview()
            self?.selectionViewController = nil
            self?.onStop?()
        }
        selectionViewController?.onDone = { [weak self] in
            self?.takeScreenshot()
        }
        canvasContainer.controls.addSubview(selectionViewController!.view)
        selectionViewController!.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func takeScreenshot() {
        Task {
            do {
                let image = try await canvasContainer.canvasViewController.takeScreenshot()
                //        print("XXX TODO: 2560")
                if let data = image.jpegData(compressionQuality: 0.75) {
                    let uploadId = generateRealmId()
                    let mediaKey = MediaKey.localFilesKeyWithAutoStorageVersion(
                        projectId: model.projectId,
                        uploadId: uploadId,
                        fileType: .jpeg,
                        annotated: false
                    )
                    let photoToAdd = PhotoToAdd(
                        timestamp: Date.now,
                        mediaKey: mediaKey,
                        thumbnail: image.imageResized(toFill: 100),
                        height2Width: image.size.height / image.size.width,
                        fileSize: Int64(data.count)
                    )
                    try await localFiles.store(data, forKey: mediaKey)
                    try await localFiles.generateAndStoreThumbnails(data, forKey: mediaKey)
                    let command = try await model.addPhotos(
                        [photoToAdd],
                        tags: [],
                        description: "",
                        toCollaborationForGeometryId: geometryId
                    )
                    try await model.run(command)
                    print("XXX uploaded image with size", image.size, command)
                    DispatchQueue.main.async { [weak self] in
                        // TODO: 2560
                        self?.selectionViewController?.view.removeFromSuperview()
                        self?.selectionViewController = nil
                        self?.onStop?()
                    }
                } else {
                    print("XXX cannot get data for image", image)
                }
            } catch {
                print("XXX error", error)
            }
        }
    }
}
