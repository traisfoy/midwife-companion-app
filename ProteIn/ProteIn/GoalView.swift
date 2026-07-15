import SwiftUI
import WidgetKit

/// The entire app: one screen to set (and later edit) the daily protein goal.
/// Everything else happens on the home screen widget.
struct GoalView: View {
    @AppStorage(ProteinStore.goalKey, store: ProteinStore.defaults)
    private var goal: Int = ProteinStore.defaultGoal

    @AppStorage("hasOnboarded", store: ProteinStore.defaults)
    private var hasOnboarded = false

    @State private var goalText = ""
    @State private var showSavedConfirmation = false
    @FocusState private var goalFieldFocused: Bool

    private var parsedGoal: Int? {
        guard let value = Int(goalText.trimmingCharacters(in: .whitespaces)),
              (1...999).contains(value) else { return nil }
        return value
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.09, green: 0.09, blue: 0.11),
                    Color(red: 0.02, green: 0.02, blue: 0.03)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 8) {
                    Text("ProteIn")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text(hasOnboarded ? "Edit your daily protein goal" : "Set your daily protein goal")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    TextField("\(ProteinStore.defaultGoal)", text: $goalText)
                        .keyboardType(.numberPad)
                        .focused($goalFieldFocused)
                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.trailing)
                        .fixedSize()
                    Text("g")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
                )

                Button(action: save) {
                    Text(showSavedConfirmation ? "Saved ✓" : "Save Goal")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(showSavedConfirmation ? Color(red: 0.20, green: 0.85, blue: 0.45) : .black)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(
                            showSavedConfirmation ? AnyShapeStyle(.white.opacity(0.08)) : AnyShapeStyle(.white),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                }
                .disabled(parsedGoal == nil)
                .opacity(parsedGoal == nil ? 0.4 : 1)
                .padding(.horizontal, 40)
                .animation(.easeInOut(duration: 0.2), value: showSavedConfirmation)

                Spacer()

                VStack(spacing: 6) {
                    Text("Today: \(ProteinStore.todayTotal)g logged")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                    Text("Add the ProteIn widget to your Home Screen —\nthat's where the tracking happens.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.3))
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            goalText = "\(goal)"
            if !hasOnboarded {
                goalFieldFocused = true
            }
        }
        .onTapGesture {
            goalFieldFocused = false
        }
    }

    private func save() {
        guard let newGoal = parsedGoal else { return }
        goal = newGoal
        hasOnboarded = true
        goalFieldFocused = false
        WidgetCenter.shared.reloadAllTimelines()

        showSavedConfirmation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showSavedConfirmation = false
        }
    }
}

#Preview {
    GoalView()
        .preferredColorScheme(.dark)
}
