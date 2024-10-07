import Foundation

class ProjectOnboarding {
    enum Step {
        case cardOnboarding
        case canvasSelectorOnboarding
        case showingCanvasSelector
        case canvasFiltersOnboarding
        case done
    }

    private(set) var currentStep: Step = .done

    private let userPreferences: UserPreferences
    weak var projectFlow: ProjectFlowController? = nil

    init(model: ProjectModel, userPreferences: UserPreferences) {
        self.userPreferences = userPreferences

        let initialStep: Step
        if model.currentUser.canCreateCollaboration() {
            // only show the card onboarding if user can create a collaboration, so is not a Guest
            // If user is a Guest then currently the card has a fixed size
            initialStep = .cardOnboarding
        } else {
            initialStep = .canvasSelectorOnboarding
        }

        currentStep = setFirstNotCompletedStep(initialStep)
    }

    func start() {
        showOnboardingForCurrentStep()
    }
    
    private func showOnboardingForCurrentStep() {
        guard let projectFlow else { return }
        switch currentStep {
        case .cardOnboarding:
            projectFlow.controls.showCardOnboardingView(aboveView: projectFlow.actionCardVC.view)
        case .canvasSelectorOnboarding:
            projectFlow.controls.showCanvasSelectorOnboardingView()
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 3) { [weak self] in
                self?.timeoutCanvasSelectorOnboarding()
            }
        case .showingCanvasSelector:
            break
        case .canvasFiltersOnboarding:
            projectFlow.controls.showCanvasFiltersOnboardingView()
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 3) { [weak self] in
                self?.timeoutCanvasFiltersOnboarding()
            }
        case .done:
            break
        }
    }

    func cardMaximized() {
        guard currentStep == .cardOnboarding else { return }

        // mark the card onboarding complete
        userPreferences.cardOnboardingComplete = true

        // and hide the onboarding animation with 1s delay
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) { [weak self] in
            guard let self else { return }
            self.projectFlow?.controls.hideCardOnboardingView()
            
            self.currentStep = self.setFirstNotCompletedStep(self.currentStep)
            self.showOnboardingForCurrentStep()
        }
    }

    func timeoutCanvasSelectorOnboarding() {
        guard currentStep == .canvasSelectorOnboarding else { return }
        userPreferences.canvasSelectorOnboardingComplete = true
        projectFlow?.controls.hideCanvasSelectorOnboardingView()
        currentStep = setFirstNotCompletedStep(currentStep)
        showOnboardingForCurrentStep()
    }

    func timeoutCanvasFiltersOnboarding() {
        guard currentStep == .canvasFiltersOnboarding else { return }
        userPreferences.canvasFiltersOnboardingComplete = true
        projectFlow?.controls.hideCanvasFiltersOnboardingView()
        currentStep = setFirstNotCompletedStep(currentStep)
        showOnboardingForCurrentStep()
    }

    func canvasSelectorTapped() {
        guard currentStep == .canvasSelectorOnboarding else { return }
        userPreferences.canvasSelectorOnboardingComplete = true
        projectFlow?.controls.hideCanvasSelectorOnboardingView()
        currentStep = .showingCanvasSelector
    }

    func canvasSelectorHidden() {
        guard currentStep == .showingCanvasSelector else { return }
        currentStep = setFirstNotCompletedStep(currentStep)
        showOnboardingForCurrentStep()
    }
    
    func canvasFiltersTapped() {
        guard currentStep == . canvasFiltersOnboarding else { return }
        userPreferences.canvasFiltersOnboardingComplete = true
        projectFlow?.controls.hideCanvasFiltersOnboardingView()
        currentStep = setFirstNotCompletedStep(currentStep)
    }

    // Calculates the next actionable step to complete based on the steps order and the information
    // about which steps are complete taken from user preferences.
    // If the initialStep is not completed it returns it.
    private func setFirstNotCompletedStep(_ initialStep: Step) -> Step {
        switch initialStep {
        case .cardOnboarding:
            if userPreferences.cardOnboardingComplete {
                return setFirstNotCompletedStep(.canvasSelectorOnboarding)
            }
        case .canvasSelectorOnboarding:
            if userPreferences.canvasSelectorOnboardingComplete {
                return setFirstNotCompletedStep(.canvasFiltersOnboarding)
            }
        case .showingCanvasSelector:
            return setFirstNotCompletedStep(.canvasFiltersOnboarding)
        case .canvasFiltersOnboarding:
            if userPreferences.canvasFiltersOnboardingComplete {
                return .done
            }
        default: break
        }
        return initialStep
    }
}
