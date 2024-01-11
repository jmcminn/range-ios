import Combine
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

    /// combine observers
    private var subscriptions = Set<AnyCancellable>()

    init(_ organizationModel: OrganizationModel) {
        self.organizationModel = organizationModel
        super.init(rootViewController: UIViewController())
        isNavigationBarHidden = true
        setViewControllers([UIHostingController(rootView: step1View())], animated: false)

        observeCameraLocation()
        observeAndAutocompleteAddress()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func step1View() -> CreateProjectStep1View {
        CreateProjectStep1View(
            model: viewModel,
            cancelAction: { [weak self] in
                self?.onCancelled?()
            },
            nextAction: { [weak self] in
                guard let self else { return }
                self.pushViewController(UIHostingController(rootView: self.step2View()), animated: true)
            }
        )
    }

    /// Observe changes in camera location and update the project location and address
    /// throttled and debounced as there's many camera location updates emitted while user is panning the map
    private func observeCameraLocation() {
        viewModel.$cameraLocation
            .removeDuplicates() // remove obvious duplicates where locations are exactly the same
            .throttle(for: 0.5, scheduler: RunLoop.main,
                      latest: true) // a lot of updates might be generated at current user position
            .removeDuplicates(by: { location1, location2 in
                // treat locations closer than 1meter as duplicates - we don't want to constantly recalculate
                // location/address if the user is standing still in the follow me mode and there's almost no update to location
                guard let location1, let location2 else { return false }
                return location1.distance(to: location2) < 1
            })
            .debounce(for: 0.5, scheduler: RunLoop.main) // don't trigger immediately, wait until it settles
            .sink { [weak self] location in
                guard let self, let location else { return }
                if let viewModelLocation = self.viewModel.location, location.distance(to: viewModelLocation) < 1,
                   !self.viewModel.address.isEmpty
                {
                    // we're very close to model location meaning that the camera animated to location selected from autocompletes,
                    // no need to recalculate the address (if it's there)
                } else {
                    // trigger location and address update
                    updateLocationAndSetAddress(location)
                }
            }
            .store(in: &subscriptions)
    }

    /// Observe changes in address and autocomplete places when model in addressAutocompletionMode
    private func observeAndAutocompleteAddress() {
        viewModel.$address
            .debounce(for: 1, scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] text in
                guard let self, self.viewModel.addressAutocompleteMode else { return }
                if text.count >= 3 {
                    self.autoCompleteAddress(text)
                } else {
                    viewModel.placeAutocompletes = []
                }
            }
            .store(in: &subscriptions)
    }

    private func autoCompleteAddress(_ name: String) {
        Task { @MainActor in
            do {
                viewModel.placeAutocompletes = try await _placeAutocompletes(for: name)
            } catch {
                Logger.mapbox
                    .error("Failed _placeAutocompletes for \(name): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// When user adjusts the map view we take the current map center and set it as project location and reverse geocode the address for it
    private func updateLocationAndSetAddress(_ coordinate: CLLocationCoordinate2D) {
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
