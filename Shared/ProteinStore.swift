import Foundation

enum Macro: String, CaseIterable, Codable {
    case protein, carbs, fat

    var label: String {
        switch self {
        case .protein: "Protein"
        case .carbs: "Carbs"
        case .fat: "Fat"
        }
    }

    var shortLabel: String {
        switch self {
        case .protein: "P"
        case .carbs: "C"
        case .fat: "F"
        }
    }

    var defaultGoal: Int {
        switch self {
        case .protein: 165
        case .carbs: 250
        case .fat: 65
        }
    }

    var next: Macro {
        switch self {
        case .protein: .carbs
        case .carbs: .fat
        case .fat: .protein
        }
    }
}

enum MacroStore {
    static let appGroupID = "group.com.mactrak.tracker"
    static let selectedMacroKey = "selectedMacro"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    static func dayStamp(for date: Date = Date()) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }

    // MARK: - Selected macro (widget state)

    static var selectedMacro: Macro {
        get {
            guard let raw = defaults.string(forKey: selectedMacroKey),
                  let macro = Macro(rawValue: raw) else { return .protein }
            return macro
        }
        set {
            defaults.set(newValue.rawValue, forKey: selectedMacroKey)
        }
    }

    // MARK: - Per-macro keys

    private static func goalKey(for macro: Macro) -> String { "goal_\(macro.rawValue)" }
    private static func entriesKey(for macro: Macro) -> String { "entries_\(macro.rawValue)" }
    private static func entriesDateKey(for macro: Macro) -> String { "entriesDate_\(macro.rawValue)" }

    // MARK: - Goals

    static func goal(for macro: Macro) -> Int {
        let stored = defaults.integer(forKey: goalKey(for: macro))
        return stored > 0 ? stored : macro.defaultGoal
    }

    static func setGoal(_ value: Int, for macro: Macro) {
        defaults.set(max(1, value), forKey: goalKey(for: macro))
    }

    // MARK: - Entries

    static func todayEntries(for macro: Macro) -> [Int] {
        guard defaults.string(forKey: entriesDateKey(for: macro)) == dayStamp() else { return [] }
        return (defaults.array(forKey: entriesKey(for: macro)) as? [Int]) ?? []
    }

    static func setTodayEntries(_ entries: [Int], for macro: Macro) {
        defaults.set(dayStamp(), forKey: entriesDateKey(for: macro))
        defaults.set(entries, forKey: entriesKey(for: macro))
    }

    static func todayTotal(for macro: Macro) -> Int {
        todayEntries(for: macro).reduce(0, +)
    }

    static func lastEntry(for macro: Macro) -> Int? {
        todayEntries(for: macro).last
    }

    static func log(_ grams: Int, for macro: Macro) {
        guard grams > 0 else { return }
        setTodayEntries(todayEntries(for: macro) + [grams], for: macro)
    }

    @discardableResult
    static func undoLastEntry(for macro: Macro) -> Int? {
        var entries = todayEntries(for: macro)
        guard let removed = entries.popLast() else { return nil }
        setTodayEntries(entries, for: macro)
        return removed
    }

    // MARK: - Migration from single-macro store

    static func migrateIfNeeded() {
        let oldGoalKey = "dailyGoal"
        let oldGoal = defaults.integer(forKey: oldGoalKey)
        guard oldGoal > 0, defaults.integer(forKey: goalKey(for: .protein)) == 0 else { return }
        setGoal(oldGoal, for: .protein)
        if let oldEntries = defaults.array(forKey: "todayEntries") as? [Int],
           let oldDate = defaults.string(forKey: "todayEntriesDate") {
            defaults.set(oldDate, forKey: entriesDateKey(for: .protein))
            defaults.set(oldEntries, forKey: entriesKey(for: .protein))
        }
    }
}

// MARK: - Backward compatibility

enum ProteinStore {
    static let goalKey = "goal_protein"
    static let defaultGoal = 165
    static var defaults: UserDefaults { MacroStore.defaults }
    static var todayTotal: Int { MacroStore.todayTotal(for: .protein) }
}
