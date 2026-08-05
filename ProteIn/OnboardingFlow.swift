import SwiftUI
import WidgetKit

struct OnboardingFlow: View {
    @State private var step: Step = .welcome

    enum Step {
        case welcome
        case choosePath
        case calculator
        case manualGoals
        case widgetGuide
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

            Group {
                switch step {
                case .welcome:
                    WelcomeStep(onContinue: { step = .choosePath })
                case .choosePath:
                    ChoosePathStep(
                        onCalculator: { step = .calculator },
                        onManual: { step = .manualGoals }
                    )
                case .calculator:
                    CalculatorStep(
                        onDone: { step = .widgetGuide },
                        onBack: { step = .choosePath }
                    )
                case .manualGoals:
                    ManualGoalsStep(
                        onDone: { step = .widgetGuide },
                        onBack: { step = .choosePath }
                    )
                case .widgetGuide:
                    WidgetGuideStep()
                }
            }
            .animation(.easeInOut(duration: 0.3), value: step)
        }
    }
}

// MARK: - Welcome

private struct WelcomeStep: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image("AppLogo")
                .resizable()
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            VStack(spacing: 10) {
                Text("JstMacros")
                    .font(.system(size: 44, weight: .heavy))
                    .foregroundStyle(.white)
                Text("Track your macros from your\nhome screen. No app to open.")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 14) {
                featureRow(icon: "plus.circle.fill", color: .blue, text: "Tap +1, +5, +10 to log grams")
                featureRow(icon: "circle.circle.fill", color: .orange, text: "Tap the ring to switch Protein / Carbs / Fat")
                featureRow(icon: "arrow.uturn.backward.circle.fill", color: .purple, text: "Undo mistakes instantly")
                featureRow(icon: "moon.fill", color: .green, text: "Resets automatically at midnight")
            }
            .padding(.horizontal, 32)

            Spacer()

            pillButton("Get Started", action: onContinue)
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
        }
    }

    private func featureRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(color)
                .frame(width: 28)
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
        }
    }
}

// MARK: - Choose Path

private struct ChoosePathStep: View {
    let onCalculator: () -> Void
    let onManual: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 10) {
                Text("Set Your Goals")
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundStyle(.white)
                Text("How would you like to start?")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            }

            VStack(spacing: 16) {
                pathCard(
                    icon: "wand.and.stars",
                    title: "Help me with my macros",
                    subtitle: "Answer a few questions and we'll suggest numbers",
                    action: onCalculator
                )
                pathCard(
                    icon: "number",
                    title: "I know my macros",
                    subtitle: "Enter protein, carbs, and fat directly",
                    action: onManual
                )
            }
            .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
    }

    private func pathCard(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Calculator

private struct CalculatorStep: View {
    let onDone: () -> Void
    let onBack: () -> Void

    enum Goal: String, CaseIterable {
        case cut, maintain, bulk

        var label: String {
            switch self {
            case .cut: "Cut"
            case .maintain: "Maintain"
            case .bulk: "Bulk"
            }
        }

        var subtitle: String {
            switch self {
            case .cut: "Lose fat"
            case .maintain: "Stay the same"
            case .bulk: "Build muscle"
            }
        }

        var icon: String {
            switch self {
            case .cut: "arrow.down.circle.fill"
            case .maintain: "equal.circle.fill"
            case .bulk: "arrow.up.circle.fill"
            }
        }

        var calorieMultiplier: Double {
            switch self {
            case .cut: 0.80
            case .maintain: 1.0
            case .bulk: 1.15
            }
        }

        var proteinPerKg: Double {
            switch self {
            case .cut: 2.2
            case .maintain: 2.0
            case .bulk: 2.0
            }
        }

        var fatPercent: Double {
            switch self {
            case .cut: 0.25
            case .maintain: 0.28
            case .bulk: 0.25
            }
        }

        var explainer: String {
            switch self {
            case .cut: "Higher protein preserves muscle while in a deficit. Moderate fat keeps hormones balanced."
            case .maintain: "Balanced split to support daily activity and recovery without gaining or losing."
            case .bulk: "Extra carbs fuel training. Protein stays high to support muscle growth."
            }
        }
    }

    enum Sex: String, CaseIterable {
        case male = "Male"
        case female = "Female"
    }

    enum WeightUnit: String, CaseIterable {
        case lbs, kg
    }

    enum HeightUnit: String, CaseIterable {
        case ft, cm
    }

    enum Activity: CaseIterable {
        case sedentary, light, moderate, active, veryActive

        var label: String {
            switch self {
            case .sedentary: "Sedentary"
            case .light: "Light"
            case .moderate: "Moderate"
            case .active: "Active"
            case .veryActive: "Very Active"
            }
        }

        var detail: String {
            switch self {
            case .sedentary: "Little to no exercise"
            case .light: "1-3 days/week"
            case .moderate: "3-5 days/week"
            case .active: "6-7 days/week"
            case .veryActive: "Athlete / 2x daily"
            }
        }

        var multiplier: Double {
            switch self {
            case .sedentary: 1.2
            case .light: 1.375
            case .moderate: 1.55
            case .active: 1.725
            case .veryActive: 1.9
            }
        }
    }

    @State private var selectedSex: Sex = .male
    @State private var weightText = ""
    @State private var weightUnit: WeightUnit = .lbs
    @State private var heightFeetText = ""
    @State private var heightInchesText = ""
    @State private var heightCmText = ""
    @State private var heightUnit: HeightUnit = .ft
    @State private var selectedActivity: Activity = .moderate
    @State private var selectedGoal: Goal = .maintain
    @State private var showResults = false
    @FocusState private var focusedInput: String?

    private var weightKg: Double? {
        guard let w = Double(weightText.trimmingCharacters(in: .whitespaces)), w > 0 else { return nil }
        return weightUnit == .kg ? w : w * 0.453592
    }

    private var heightCm: Double? {
        if heightUnit == .cm {
            guard let cm = Double(heightCmText.trimmingCharacters(in: .whitespaces)), cm > 0 else { return nil }
            return cm
        } else {
            guard let ft = Double(heightFeetText.trimmingCharacters(in: .whitespaces)), ft >= 0 else { return nil }
            let inches = Double(heightInchesText.trimmingCharacters(in: .whitespaces)) ?? 0
            let totalInches = ft * 12 + inches
            guard totalInches > 0 else { return nil }
            return totalInches * 2.54
        }
    }

    private var recommendation: (protein: Int, carbs: Int, fat: Int)? {
        guard let kg = weightKg, let cm = heightCm else { return nil }

        let bmr: Double
        switch selectedSex {
        case .male:
            bmr = 10 * kg + 6.25 * cm - 5 * 30 + 5
        case .female:
            bmr = 10 * kg + 6.25 * cm - 5 * 30 - 161
        }

        let tdee = bmr * selectedActivity.multiplier
        let targetCal = tdee * selectedGoal.calorieMultiplier

        let proteinG = kg * selectedGoal.proteinPerKg
        let fatCal = targetCal * selectedGoal.fatPercent
        let fatG = fatCal / 9
        let carbCal = targetCal - (proteinG * 4) - fatCal
        let carbG = max(carbCal / 4, 50)

        return (protein: Int(proteinG), carbs: Int(carbG), fat: Int(fatG))
    }

    private var inputsValid: Bool {
        weightKg != nil && heightCm != nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                if !showResults {
                    inputSection
                } else if let rec = recommendation {
                    resultsSection(rec)
                }
            }
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture { focusedInput = nil }
    }

    private var inputSection: some View {
        VStack(spacing: 20) {
            VStack(spacing: 10) {
                Text("About You")
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundStyle(.white)
                Text("We'll use this to estimate your macros")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            }

            inputCard(highlight: false) {
                VStack(spacing: 8) {
                    Text("Sex")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                    Picker("", selection: $selectedSex) {
                        ForEach(Sex.allCases, id: \.self) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
            }

            inputCard(highlight: focusedInput == "weight") {
                VStack(spacing: 8) {
                    Text("Weight")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                    HStack(spacing: 12) {
                        TextField("180", text: $weightText)
                            .keyboardType(.decimalPad)
                            .focused($focusedInput, equals: "weight")
                            .font(.system(size: 36, weight: .heavy))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                        Picker("", selection: $weightUnit) {
                            ForEach(WeightUnit.allCases, id: \.self) { u in
                                Text(u.rawValue).tag(u)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 100)
                    }
                }
            }

            inputCard(highlight: focusedInput == "feet" || focusedInput == "inches" || focusedInput == "cm") {
                VStack(spacing: 8) {
                    Text("Height")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                    HStack(spacing: 12) {
                        if heightUnit == .ft {
                            HStack(spacing: 2) {
                                TextField("5", text: $heightFeetText)
                                    .keyboardType(.numberPad)
                                    .focused($focusedInput, equals: "feet")
                                    .font(.system(size: 36, weight: .heavy))
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.trailing)
                                    .frame(minWidth: 30, maxWidth: 50)
                                Text("ft")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.45))
                                TextField("10", text: $heightInchesText)
                                    .keyboardType(.numberPad)
                                    .focused($focusedInput, equals: "inches")
                                    .font(.system(size: 36, weight: .heavy))
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.trailing)
                                    .frame(minWidth: 30, maxWidth: 50)
                                Text("in")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.45))
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            HStack(spacing: 4) {
                                TextField("170", text: $heightCmText)
                                    .keyboardType(.numberPad)
                                    .focused($focusedInput, equals: "cm")
                                    .font(.system(size: 36, weight: .heavy))
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                                Text("cm")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.45))
                            }
                            .frame(maxWidth: .infinity)
                        }
                        Picker("", selection: $heightUnit) {
                            ForEach(HeightUnit.allCases, id: \.self) { u in
                                Text(u.rawValue).tag(u)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 100)
                    }
                }
            }

            // Activity level
            VStack(spacing: 8) {
                Text("Activity Level")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
                VStack(spacing: 8) {
                    ForEach(Activity.allCases, id: \.self) { activity in
                        activityRow(activity)
                    }
                }
            }
            .padding(.horizontal, 24)

            // Goal
            VStack(spacing: 8) {
                Text("Goal")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
                HStack(spacing: 12) {
                    ForEach(Goal.allCases, id: \.self) { goal in
                        goalPill(goal)
                    }
                }
            }
            .padding(.horizontal, 24)

            pillButton("Calculate My Macros") {
                withAnimation { showResults = true }
            }
            .disabled(!inputsValid)
            .opacity(inputsValid ? 1 : 0.4)
            .padding(.horizontal, 40)
            .padding(.top, 4)
        }
    }

    private func inputCard<Content: View>(highlight: Bool, @ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        highlight ? Color.blue.opacity(0.5) : .white.opacity(0.08),
                        lineWidth: highlight ? 1 : 0.5
                    )
            )
            .animation(.easeInOut(duration: 0.15), value: highlight)
            .padding(.horizontal, 24)
    }

    private func activityRow(_ activity: Activity) -> some View {
        Button {
            selectedActivity = activity
        } label: {
            HStack(spacing: 12) {
                Text(activity.label)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(selectedActivity == activity ? .white : .white.opacity(0.5))
                Text(activity.detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
                Spacer()
                if selectedActivity == activity {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                selectedActivity == activity ? .white.opacity(0.10) : .white.opacity(0.04),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        selectedActivity == activity ? .blue.opacity(0.4) : .white.opacity(0.06),
                        lineWidth: selectedActivity == activity ? 1 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func goalPill(_ goal: Goal) -> some View {
        Button {
            selectedGoal = goal
        } label: {
            VStack(spacing: 6) {
                Image(systemName: goal.icon)
                    .font(.system(size: 22))
                Text(goal.label)
                    .font(.system(size: 15, weight: .bold))
                Text(goal.subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .foregroundStyle(selectedGoal == goal ? .white : .white.opacity(0.5))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                selectedGoal == goal ? .white.opacity(0.12) : .white.opacity(0.04),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        selectedGoal == goal ? .white.opacity(0.2) : .white.opacity(0.06),
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func resultsSection(_ rec: (protein: Int, carbs: Int, fat: Int)) -> some View {
        VStack(spacing: 24) {
            VStack(spacing: 10) {
                Text("Your Macros")
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundStyle(.white)
                Text("Based on your stats and \(selectedGoal.label.lowercased()) goal")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            }

            VStack(spacing: 16) {
                resultRow(macro: .protein, value: rec.protein)
                resultRow(macro: .carbs, value: rec.carbs)
                resultRow(macro: .fat, value: rec.fat)
            }
            .padding(.horizontal, 24)

            Text(selectedGoal.explainer)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Text("Estimated using the Mifflin-St Jeor equation\nwith \(selectedActivity.label.lowercased()) activity. Adjust as needed.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.3))
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                pillButton("Use These Macros") {
                    MacroStore.setGoal(rec.protein, for: .protein)
                    MacroStore.setGoal(rec.carbs, for: .carbs)
                    MacroStore.setGoal(rec.fat, for: .fat)
                    WidgetCenter.shared.reloadAllTimelines()
                    onDone()
                }

                Button {
                    withAnimation { showResults = false }
                } label: {
                    Text("Adjust inputs")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 40)
        }
    }

    private func resultRow(macro: Macro, value: Int) -> some View {
        HStack {
            Circle()
                .fill(macro.ringColor)
                .frame(width: 10, height: 10)
            Text(macro.label)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
            Text("\(value)g")
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
        )
    }
}

// MARK: - Manual Goals

private struct ManualGoalsStep: View {
    let onDone: () -> Void
    let onBack: () -> Void

    @State private var proteinText = ""
    @State private var carbsText = ""
    @State private var fatText = ""
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
        ScrollView {
            VStack(spacing: 28) {
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                VStack(spacing: 10) {
                    Text("Your Macros")
                        .font(.system(size: 34, weight: .heavy))
                        .foregroundStyle(.white)
                    Text("Enter your daily goals in grams")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                }

                VStack(spacing: 16) {
                    macroRow(label: "Protein", text: $proteinText, macro: .protein)
                    macroRow(label: "Carbs", text: $carbsText, macro: .carbs)
                    macroRow(label: "Fat", text: $fatText, macro: .fat)
                }
                .padding(.horizontal, 24)

                pillButton("Save Goals") {
                    guard let p = parsed(proteinText),
                          let c = parsed(carbsText),
                          let f = parsed(fatText) else { return }
                    MacroStore.setGoal(p, for: .protein)
                    MacroStore.setGoal(c, for: .carbs)
                    MacroStore.setGoal(f, for: .fat)
                    WidgetCenter.shared.reloadAllTimelines()
                    onDone()
                }
                .disabled(!allValid)
                .opacity(allValid ? 1 : 0.4)
                .padding(.horizontal, 40)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear { focusedField = .protein }
        .onTapGesture { focusedField = nil }
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
}

// MARK: - Widget Guide

private struct WidgetGuideStep: View {
    @AppStorage("hasOnboarded", store: MacroStore.defaults)
    private var hasOnboarded = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer().frame(height: 20)

                VStack(spacing: 10) {
                    Text("Add Your Widget")
                        .font(.system(size: 34, weight: .heavy))
                        .foregroundStyle(.white)
                    Text("The widget is where all the\ntracking happens")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 16) {
                    guideStep(number: 1, text: "Long press your Home Screen")
                    guideStep(number: 2, text: "Tap Edit, then Add Widget")
                    guideStep(number: 3, text: "Search \"JstMacros\"")
                    guideStep(number: 4, text: "Add the medium widget")
                }
                .padding(.horizontal, 32)

                Image("WidgetPreview")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .white.opacity(0.05), radius: 12, y: 4)
                    .padding(.horizontal, 40)

                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        tipPill(icon: "hand.tap.fill", text: "Tap +1, +5, +10\nto log grams")
                        tipPill(icon: "circle.circle", text: "Tap the ring to\nswitch Protein / Carbs / Fat")
                    }
                    HStack(spacing: 12) {
                        tipPill(icon: "arrow.uturn.backward", text: "Tap undo to\nremove last entry")
                        tipPill(icon: "moon.stars.fill", text: "Totals reset\nat midnight")
                    }
                }
                .padding(.horizontal, 24)

                pillButton("I'm Ready") {
                    hasOnboarded = true
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
    }

    private func guideStep(number: Int, text: String) -> some View {
        HStack(spacing: 16) {
            Text("\(number)")
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(.black)
                .frame(width: 28, height: 28)
                .background(.white, in: Circle())
            Text(text)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
        }
    }

    private func tipPill(icon: String, text: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.white.opacity(0.6))
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Shared Button

private func pillButton(_ label: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(label)
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
