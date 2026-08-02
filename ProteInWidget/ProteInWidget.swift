import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Timeline

struct MacroEntry: TimelineEntry {
    let date: Date
    let macro: Macro
    let total: Int
    let goal: Int
    let lastEntry: Int?
    let proteinTotal: Int
    let carbsTotal: Int
    let fatTotal: Int
    let proteinGoal: Int
    let carbsGoal: Int
    let fatGoal: Int

    var progress: Double {
        guard goal > 0 else { return 0 }
        return Double(total) / Double(goal)
    }

    var remaining: Int {
        max(0, goal - total)
    }
}

struct MacroProvider: TimelineProvider {
    func placeholder(in context: Context) -> MacroEntry {
        MacroEntry(
            date: .now, macro: .protein, total: 94, goal: 165, lastEntry: 10,
            proteinTotal: 94, carbsTotal: 120, fatTotal: 30,
            proteinGoal: 165, carbsGoal: 250, fatGoal: 65
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (MacroEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MacroEntry>) -> Void) {
        let startOfToday = Calendar.current.startOfDay(for: .now)
        let nextMidnight = Calendar.current.date(byAdding: .day, value: 1, to: startOfToday) ?? .now.addingTimeInterval(86_400)
        completion(Timeline(entries: [currentEntry()], policy: .after(nextMidnight)))
    }

    private func currentEntry() -> MacroEntry {
        let selected = MacroStore.selectedMacro
        return MacroEntry(
            date: .now,
            macro: selected,
            total: MacroStore.todayTotal(for: selected),
            goal: MacroStore.goal(for: selected),
            lastEntry: MacroStore.lastEntry(for: selected),
            proteinTotal: MacroStore.todayTotal(for: .protein),
            carbsTotal: MacroStore.todayTotal(for: .carbs),
            fatTotal: MacroStore.todayTotal(for: .fat),
            proteinGoal: MacroStore.goal(for: .protein),
            carbsGoal: MacroStore.goal(for: .carbs),
            fatGoal: MacroStore.goal(for: .fat)
        )
    }
}

// Keep old type name for the widget bundle
typealias ProteinEntry = MacroEntry
typealias ProteinProvider = MacroProvider

// MARK: - Widget

struct ProteInWidget: Widget {
    let kind = "ProteInWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MacroProvider()) { entry in
            MacroWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [
                            Color(red: 0.09, green: 0.09, blue: 0.11),
                            Color(red: 0.02, green: 0.02, blue: 0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName("JstMacros")
        .description("Track protein, carbs, and fat with one tap.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - View

struct MacroWidgetView: View {
    let entry: MacroEntry

    private var ringColor: Color {
        entry.macro.progressColor(for: entry.progress)
    }

    var body: some View {
        HStack(spacing: 14) {
            progressSection
            buttonSection
        }
    }

    private var progressSection: some View {
        VStack(spacing: 4) {
            Button(intent: SwitchMacroIntent()) {
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.10), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: min(entry.progress, 1))
                        .stroke(ringColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        HStack(alignment: .firstTextBaseline, spacing: 1) {
                            Text("\(entry.total)")
                                .font(.system(size: 26, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .invalidatableContent()
                            Text("/\(entry.goal)g")
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                        Text(entry.macro.label)
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(ringColor.opacity(0.9))
                            .invalidatableContent()
                    }
                    .padding(.horizontal, 8)
                }
                .frame(width: 88, height: 88)
            }
            .buttonStyle(.plain)

            Group {
                if entry.total >= entry.goal {
                    Text("GOAL HIT")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(ringColor)
                } else {
                    Text("\(entry.remaining)g left")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .invalidatableContent()

            miniSummary
        }
    }

    private var miniSummary: some View {
        HStack(spacing: 6) {
            ForEach(Macro.allCases, id: \.self) { macro in
                let isCurrent = macro == entry.macro
                let total = macroTotal(for: macro)
                let goal = macroGoal(for: macro)
                Text("\(macro.shortLabel):\(total)")
                    .font(.system(size: 8, weight: isCurrent ? .bold : .medium, design: .rounded))
                    .foregroundStyle(isCurrent ? ringColor.opacity(0.9) : .white.opacity(0.35))
                    .invalidatableContent()
                    .opacity(total >= goal ? 1 : 0.8)
            }
        }
    }

    private func macroTotal(for macro: Macro) -> Int {
        switch macro {
        case .protein: entry.proteinTotal
        case .carbs: entry.carbsTotal
        case .fat: entry.fatTotal
        }
    }

    private func macroGoal(for macro: Macro) -> Int {
        switch macro {
        case .protein: entry.proteinGoal
        case .carbs: entry.carbsGoal
        case .fat: entry.fatGoal
        }
    }

    private var buttonSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                addButton(1)
                addButton(5)
                addButton(10)
            }
            undoButton
        }
        .frame(maxWidth: .infinity)
    }

    private func addButton(_ amount: Int) -> some View {
        Button(intent: LogMacroIntent(amount: amount)) {
            VStack(spacing: 1) {
                Text("+\(amount)")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("grams")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var undoButton: some View {
        Button(intent: UndoMacroIntent()) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 9, weight: .bold))
                Text(entry.lastEntry.map { "Undo \($0)g" } ?? "Undo")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .invalidatableContent()
            }
            .foregroundStyle(.white.opacity(entry.lastEntry == nil ? 0.25 : 0.6))
            .frame(maxWidth: .infinity, minHeight: 24)
            .background(.white.opacity(0.05), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(entry.lastEntry == nil)
    }
}

// MARK: - Previews

#Preview(as: .systemMedium) {
    ProteInWidget()
} timeline: {
    MacroEntry(date: .now, macro: .protein, total: 94, goal: 165, lastEntry: 10,
               proteinTotal: 94, carbsTotal: 120, fatTotal: 30,
               proteinGoal: 165, carbsGoal: 250, fatGoal: 65)
    MacroEntry(date: .now, macro: .carbs, total: 120, goal: 250, lastEntry: 5,
               proteinTotal: 94, carbsTotal: 120, fatTotal: 30,
               proteinGoal: 165, carbsGoal: 250, fatGoal: 65)
    MacroEntry(date: .now, macro: .fat, total: 65, goal: 65, lastEntry: 10,
               proteinTotal: 165, carbsTotal: 200, fatTotal: 65,
               proteinGoal: 165, carbsGoal: 250, fatGoal: 65)
}
