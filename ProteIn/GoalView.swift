import SwiftUI
import WidgetKit

struct GoalView: View {
    @AppStorage("hasOnboarded", store: MacroStore.defaults)
    private var hasOnboarded = false

    @State private var proteinText = ""
    @State private var carbsText = ""
    @State private var fatText = ""
    @State private var showSavedConfirmation = false
    @State private var showHelp = false
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
                    HStack {
                        Spacer()
                        Button { showHelp = true } label: {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                    VStack(spacing: 12) {
                        Image("AppLogo")
                            .resizable()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                        Text("JstMacros")
                            .font(.system(size: 40, weight: .heavy))
                            .foregroundStyle(.white)
                        Text("Edit your daily goals")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                    }

                    VStack(spacing: 16) {
                        macroRow(label: "Protein", text: $proteinText, macro: .protein)
                        macroRow(label: "Carbs", text: $carbsText, macro: .carbs)
                        macroRow(label: "Fat", text: $fatText, macro: .fat)
                    }
                    .padding(.horizontal, 24)

                    Button(action: save) {
                        Text(showSavedConfirmation ? "Saved \u{2713}" : "Save Goals")
                            .font(.system(size: 17, weight: .bold))
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
                        Text("Add the JstMacros widget to your Home Screen.\nThat's where the tracking happens.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.3))
                            .multilineTextAlignment(.center)
                        Text("Tap the ring on the widget to switch macros.")
                            .font(.system(size: 12, weight: .medium))
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
        }
        .onTapGesture {
            focusedField = nil
        }
        .sheet(isPresented: $showHelp) {
            HelpSheet()
        }
    }

    private func macroRow(label: String, text: Binding<String>, macro: Macro) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 72, alignment: .leading)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                TextField("\(macro.defaultGoal)", text: text)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: macro)
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.trailing)
                    .fixedSize()
                Text("g")
                    .font(.system(size: 16, weight: .bold))
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
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                    Text(macro.label)
                        .font(.system(size: 11, weight: .medium))
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

// MARK: - Help Sheet

private struct HelpSheet: View {
    @AppStorage("hasOnboarded", store: MacroStore.defaults)
    private var hasOnboarded = false
    @Environment(\.dismiss) private var dismiss

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
                VStack(spacing: 28) {
                    HStack {
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                    VStack(spacing: 10) {
                        Text("How to Use")
                            .font(.system(size: 28, weight: .heavy))
                            .foregroundStyle(.white)
                        Text("Everything happens on your\nhome screen widget")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 16) {
                        helpRow(icon: "plus.circle.fill", color: .blue,
                                title: "Log grams",
                                detail: "Tap +1, +5, or +10 on the widget to add grams to your current macro.")
                        helpRow(icon: "circle.circle.fill", color: .orange,
                                title: "Switch macros",
                                detail: "Tap the progress ring to cycle between Protein, Carbs, and Fat.")
                        helpRow(icon: "arrow.uturn.backward.circle.fill", color: .purple,
                                title: "Undo",
                                detail: "Tap the undo button to remove your last entry.")
                        helpRow(icon: "moon.fill", color: .green,
                                title: "Daily reset",
                                detail: "All totals reset to zero automatically at midnight.")
                    }
                    .padding(.horizontal, 24)

                    VStack(spacing: 16) {
                        Text("Adding the Widget")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)

                        VStack(spacing: 12) {
                            stepRow(number: 1, text: "Long press your Home Screen")
                            stepRow(number: 2, text: "Tap Edit > Add Widget (or the + button)")
                            stepRow(number: 3, text: "Search \"JstMacros\"")
                            stepRow(number: 4, text: "Add the medium widget")
                        }
                    }
                    .padding(.horizontal, 24)

                    Button {
                        hasOnboarded = false
                        dismiss()
                    } label: {
                        Text("Recalculate My Macros")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
                            )
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func helpRow(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
        }
    }

    private func stepRow(number: Int, text: String) -> some View {
        HStack(spacing: 14) {
            Text("\(number)")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(.black)
                .frame(width: 24, height: 24)
                .background(.white, in: Circle())
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
        }
    }
}

#Preview {
    GoalView()
        .preferredColorScheme(.dark)
}
