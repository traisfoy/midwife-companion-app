import SwiftUI
import WidgetKit

struct GoalView: View {
    @AppStorage("hasOnboarded", store: MacroStore.defaults)
    private var hasOnboarded = false

    @State private var proteinText = ""
    @State private var carbsText = ""
    @State private var fatText = ""
    @State private var showSavedConfirmation = false
    @FocusState private var focusedField: Macro?

    private func parsed(_ text: String) -> Int? {
        guard let v = Int(text.trimmingCharacters(in: .whitespaces)),
              (1...999).contains(v) else { return nil }
        return v
    }

    private var allValid: Bool {
        parsed(proteinText) != nil &&
        parsed(carbsText) != nil &&
        parsed(fatText) != nil
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

            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 20)

                    VStack(spacing: 12) {
                        Image("AppLogo")
                            .resizable()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                        Text("JstMacros")
                            .font(.system(size: 40, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Text(hasOnboarded ? "Edit your daily goals" : "Set your daily goals")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                    }

                    VStack(spacing: 16) {
                        macroRow(label: "Protein", text: $proteinText, macro: .protein)
                        macroRow(label: "Carbs", text: $carbsText, macro: .carbs)
                        macroRow(label: "Fat", text: $fatText, macro: .fat)
                    }
                    .padding(.horizontal, 24)

                    Button(action: save) {
                        Text(showSavedConfirmation ? "Saved ✓" : "Save Goals")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(showSavedConfirmation ? Color(red: 0.20, green: 0.85, blue: 0.45) : .black)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(
                                showSavedConfirmation ? AnyShapeStyle(.white.opacity(0.08)) : AnyShapeStyle(.white),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                            )
                    }
                    .disabled(!allValid)
                    .opacity(allValid ? 1 : 0.4)
                    .padding(.horizontal, 40)
                    .animation(.easeInOut(duration: 0.2), value: showSavedConfirmation)

                    todaySummary

                    VStack(spacing: 6) {
                        Text("Add the JstMacros widget to your Home Screen —\nthat's where the tracking happens.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.3))
                            .multilineTextAlignment(.center)
                        Text("Tap the ring on the widget to switch macros.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .padding(.bottom, 24)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            MacroStore.migrateIfNeeded()
            proteinText = "\(MacroStore.goal(for: .protein))"
            carbsText = "\(MacroStore.goal(for: .carbs))"
            fatText = "\(MacroStore.goal(for: .fat))"
            if !hasOnboarded {
                focusedField = .protein
            }
        }
        .onTapGesture {
            focusedField = nil
        }
    }

    private func macroRow(label: String, text: Binding<String>, macro: Macro) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 72, alignment: .leading)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                TextField("\(macro.defaultGoal)", text: text)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: macro)
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.trailing)
                    .fixedSize()
                Text("g")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    focusedField == macro ? macro.ringColor.opacity(0.5) : .white.opacity(0.08),
                    lineWidth: focusedField == macro ? 1 : 0.5
                )
        )
        .animation(.easeInOut(duration: 0.15), value: focusedField)
    }

    private var todaySummary: some View {
        HStack(spacing: 20) {
            ForEach(Macro.allCases, id: \.self) { macro in
                VStack(spacing: 2) {
                    Text("\(MacroStore.todayTotal(for: macro))g")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                    Text(macro.label)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
        }
        .padding(.top, 4)
    }

    private func save() {
        guard let p = parsed(proteinText),
              let c = parsed(carbsText),
              let f = parsed(fatText) else { return }
        MacroStore.setGoal(p, for: .protein)
        MacroStore.setGoal(c, for: .carbs)
        MacroStore.setGoal(f, for: .fat)
        hasOnboarded = true
        focusedField = nil
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
