import SwiftUI

@main
struct ProteInApp: App {
    @AppStorage("hasOnboarded", store: MacroStore.defaults)
    private var hasOnboarded = false

    var body: some Scene {
        WindowGroup {
            if hasOnboarded {
                GoalView()
                    .preferredColorScheme(.dark)
            } else {
                OnboardingFlow()
                    .preferredColorScheme(.dark)
            }
        }
    }
}
