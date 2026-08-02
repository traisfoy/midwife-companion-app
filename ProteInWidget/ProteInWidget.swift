import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Timeline

struct ProteinEntry: TimelineEntry {
    let date: Date
    let total: Int
    let goal: Int
    let lastEntry: Int?

    var progress: Double {
        guard goal > 0 else { return 0 }
        return Double(total) / Double(goal)
    }

    var remaining: Int {
        max(0, goal - total)
    }
}

struct ProteinProvider: TimelineProvider {
    func placeholder(in context: Context) -> ProteinEntry {
        ProteinEntry(date: .now, total: 94, goal: 165, lastEntry: 10)
    }

    func getSnapshot(in context: Context, completion: @escaping (ProteinEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ProteinEntry>) -> Void) {
        // One entry reflecting current state; interactive buttons trigger an
        // immediate reload. Refresh after midnight so the total visibly
        // resets to 0 for the new day.
        let startOfToday = Calendar.current.startOfDay(for: .now)
        let nextMidnight = Calendar.current.date(byAdding: .day, value: 1, to: startOfToday) ?? .now.addingTimeInterval(86_400)
        completion(Timeline(entries: [currentEntry()], policy: .after(nextMidnight)))
    }

    private func currentEntry() -> ProteinEntry {
        ProteinEntry(
            date: .now,
            total: ProteinStore.todayTotal,
            goal: ProteinStore.goal,
            lastEntry: ProteinStore.lastEntry
        )
    }
}

// MARK: - Widget

struct ProteInWidget: Widget {
    let kind = "ProteInWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ProteinProvider()) { entry in
            ProteInWidgetView(entry: entry)
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
        .description("Track today's protein and log grams with one tap.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - View

struct ProteInWidgetView: View {
    let entry: ProteinEntry

    private var ringColor: Color {
        Self.ringColor(for: entry.progress)
    }

    /// Blue at 0%, blending toward yellow as the goal approaches, green at 100%.
    static func ringColor(for progress: Double) -> Color {
        if progress >= 1 { return Color(red: 0.20, green: 0.85, blue: 0.45) }
        let t = min(max(progress, 0), 1)
        // Hue slides from blue (0.58) to yellow (0.13).
        return Color(hue: 0.58 - 0.45 * t, saturation: 0.85, brightness: 0.95)
    }

    var body: some View {
        HStack(spacing: 14) {
            progressSection
            buttonSection
        }
    }

    private var progressSection: some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.10), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: min(entry.progress, 1))
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("\(entry.total)")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .invalidatableContent()
                    Text("/\(entry.goal)g")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                }
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, 10)
            }
            .frame(width: 92, height: 92)

            Group {
                if entry.total >= entry.goal {
                    Text("GOAL HIT")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(ringColor)
                } else {
                    Text("\(entry.remaining)g left")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .invalidatableContent()
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
        Button(intent: LogProteinIntent(amount: amount)) {
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
        Button(intent: UndoProteinIntent()) {
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
    ProteinEntry(date: .now, total: 0, goal: 165, lastEntry: nil)
    ProteinEntry(date: .now, total: 94, goal: 165, lastEntry: 10)
    ProteinEntry(date: .now, total: 170, goal: 165, lastEntry: 5)
}
