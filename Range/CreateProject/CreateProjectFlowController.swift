import CoreLocation
import FirebaseFunctions
import Foundation
import OrderedCollections
import OSLog
import SwiftUI
import UIKit

/// Controls the "create project" wizard
class CreateProjectFlowController: UINavigationController {
    let organizationModel: OrganizationModel
    let viewModel = CreateProjectViewModel()
    var onCancelled: (() -> Void)?
    /// Callback for project created with given project id
    var onProjectCreated: ((String) -> Void)?

    init(_ organizationModel: OrganizationModel) {
        self.organizationModel = organizationModel
        super.init(rootViewController: UIViewController())
        isNavigationBarHidden = true
        setViewControllers([UIHostingController(rootView: step1View())], animated: false)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func step1View() -> CreateProjectStep1View {
        CreateProjectStep1View(
            model: viewModel,
            onMapTap: { [weak self] coordinate in
                self?.handleMapTap(coordinate)
            },
            cancelAction: { [weak self] in
                self?.onCancelled?()
            },
            nextAction: { [weak self] in
                guard let self else { return }
                self.pushViewController(UIHostingController(rootView: self.step2View()), animated: true)
            }
        )
    }

    private func handleMapTap(_ coordinate: CLLocationCoordinate2D) {
        // end editing so the keyboard for address is hidden if shown
        view.endEditing(true)
        // reset the address, we'll be fetching a new one
        viewModel.address = ""

        // Mapbox  MapViewAnnotation was not always responding to location changes without resetting to nil... (???)
        viewModel.location = nil
        DispatchQueue.main.async {
            self.viewModel.location = coordinate
        }
        /// Fetch the place name using mapbox reverse geocoding
        Task { @MainActor in
            do {
                if let placeName = try await _placeName(for: coordinate) {
                    self.viewModel.address = placeName
                } else {
                    self.viewModel.address = ""
                }
            } catch {
                Logger.mapbox.error("Failed _placeName: \(error.localizedDescription, privacy: .public)")
                ToastWindow.shared.showError(text: "Failed to fetch the address for selected location")
            }
        }
    }

    private func step2View() -> CreateProjectStep2View {
        CreateProjectStep2View(
            model: viewModel,
            showTypeSelectorAction: { [weak self] in
                self?.showTypeSelector()
            },
            showTagSourceSelectorAction: { [weak self] in
                self?.showTagSourceSelector()
            },
            whatAreProjectTagsAction: { [weak self] in
                self?.showWhatAreProjectTagsCard()
            },
            backAction: { [weak self] in
                self?.popViewController(animated: true)
            },
            createProjectAction: { [weak self] in
                Task {
                    await self?.showProgressAndCreateProject()
                }
            }
        )
    }

    private func showTypeSelector() {
        let projectTypes: OrderedDictionary<String, String> = [
            "Architecture": "ARCHITECTURE_ID",
            "Construction": "CONSTRUCTION_ID",
            "Landscaping": "LANDSCAPING_ID",
            "Remodel / Retrofit": "RETROFIT_ID",
            "Other": "OTHER_ID",
        ]
        let pickerVC = StringPickerCardViewController(
            title: "Select a project type",
            strings: projectTypes.keys.elements,
            selectedString: viewModel.typeName
        )
        pickerVC.onStringSelected = { [weak self] projectTypeName in
            guard let self else { return }
            viewModel.typeName = projectTypeName
            viewModel.typeId = projectTypes[projectTypeName]
        }
        pickerVC.installAndShowCard(in: self)
    }

    private func showTagSourceSelector() {
        let names = Array(organizationModel.projects.map(\.name))
        let pickerVC = StringPickerCardViewController(
            title: "Select a project",
            strings: names,
            selectedString: viewModel.typeName
        )
        pickerVC.onStringSelected = { [weak self] projectName in
            guard let self else { return }
            guard let projectId = self.organizationModel.projects.first(where: { $0.name == projectName })?.id
            else { return }
            viewModel.tagSourceName = projectName
            viewModel.tagSourceId = projectId
        }
        pickerVC.installAndShowCard(in: self)
    }

    private func showWhatAreProjectTagsCard() {
        SheetCardViewController(
            icon: UIImage(systemName: "tag"),
            title: "What are project tags?",
            description: "Populate your projects tags using gone of your existing projects, or start from scratch and add new tags as you go."
        ).installAndShowCard(in: self)
    }

    @MainActor
    private func showProgressAndCreateProject() async {
        viewModel.createProjectOngoing = true
        do {
            defer {
                viewModel.createProjectOngoing = false
            }
            let projectId = try await organizationModel.createProject(viewModel)
            ToastWindow.shared.showSuccess(text: "Project created")
            onProjectCreated?(projectId)
        } catch {
            ToastWindow.shared.showError(text: "Project creation failed: \(error.localizedDescription)")
            Logger.functions.error("Project creation failed: \(error.localizedDescription)")
        }
    }
}
