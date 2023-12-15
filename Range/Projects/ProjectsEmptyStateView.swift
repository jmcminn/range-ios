import SwiftUI

struct ProjectsEmptyStateView: View {
    enum State {
        case noOrganization, noProjectsAdmin, noProjectsCollaborator
    }

    var state: State
    var stateDescription: String {
        switch state {
        case .noOrganization:
            return "You do not belong to an Organization. Organizations are first created in the desktop web app, where you will also create your first project.\n\nLog in at app.range.io/login on a dekstop computer to get started."
        case .noProjectsAdmin:
            return "Your Organization has no projects. Create a new project to get started."
        case .noProjectsCollaborator:
            return "Your Organization admins have been notified and will be assigning you projects which will show up here."
        }
    }

    let createProjectAction: () -> Void

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            Image("large_task_pin")
            Text("Welcome to Range 😎")
                .font(.title2.bold())
                .kerning(0.35)
                .multilineTextAlignment(.center)
                .foregroundColor(.dynamic(.Neutral_04))
            Text(stateDescription)
                .multilineTextAlignment(.center)
                .foregroundColor(.dynamic(.Neutral_05))

            if state == .noProjectsAdmin {
                Button("Create Project", action: createProjectAction)
                    .buttonStyle(BlueButtonStyle())
            }

            VStack(alignment: .center, spacing: 16) {
                Text("Learn about Range")
                    .font(.title2.bold())
                    .kerning(0.38)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.dynamic(.Neutral_04))

                Text(
                    "Through our short snippet video tutorials, you’ll master everything you need to know about the Range."
                )
                .multilineTextAlignment(.center)
                .foregroundColor(.dynamic(.Neutral_05))

                Button(action: {
                    if let url = URL(string: aboutRangeVimeoUrl) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack(alignment: .center, spacing: 10) {
                        Image("learn_about_range")
                        Text("Learn about Range")
                            .font(.body.bold())
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .background(
                        LinearGradient(
                            stops: [
                                Gradient.Stop(color: Color(red: 0.44, green: 0.38, blue: 0.91), location: 0.00),
                                Gradient.Stop(color: Color(red: 0.83, green: 0.36, blue: 0.48), location: 1.00),
                            ],
                            startPoint: UnitPoint(x: 0.54, y: 1.96),
                            endPoint: UnitPoint(x: 0.88, y: -0.77)
                        )
                    )
                    .cornerRadius(999)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .top)
            .background(Color.dynamic(.Neutral_09))
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16)
                .inset(by: 0.5)
                .stroke(Color.dynamic(.Neutral_07), lineWidth: 1))
        }
        .padding(24)
    }
}

struct ProjectsEmptyStateView_Previews: PreviewProvider {
    static var previews: some View {
        ProjectsEmptyStateView(state: .noOrganization, createProjectAction: {})
        ProjectsEmptyStateView(state: .noProjectsAdmin, createProjectAction: {})
        ProjectsEmptyStateView(state: .noProjectsCollaborator, createProjectAction: {})
    }
}
