import Foundation

/// Single source of truth for protein data, shared between the app and the
/// widget extension via an App Group UserDefaults suite.
///
/// IMPORTANT: `appGroupID` must match the App Group in BOTH entitlements files
/// (ProteIn/ProteIn.entitlements and ProteInWidget/ProteInWidget.entitlements)
/// and must be registered on your Apple Developer account.
enum ProteinStore {
    static let appGroupID = "group.com.protein.tracker"

    static let goalKey = "dailyGoal"
    static let entriesKey = "todayEntries"
    static let entriesDateKey = "todayEntriesDate"

    static let defaultGoal = 165

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    /// Stable stamp for "today" in the user's current calendar/time zone.
    /// Entries stored under a stale stamp are ignored, which makes the daily
    /// total reset itself automatically at midnight without any timer.
    static func dayStamp(for date: Date = Date()) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }

    static var goal: Int {
        get {
            let stored = defaults.integer(forKey: goalKey)
            return stored > 0 ? stored : defaultGoal
        }
        set {
            defaults.set(max(1, newValue), forKey: goalKey)
        }
    }

    /// Grams logged today, oldest first. Reads from a previous day return [].
    static var todayEntries: [Int] {
        get {
            guard defaults.string(forKey: entriesDateKey) == dayStamp() else { return [] }
            return (defaults.array(forKey: entriesKey) as? [Int]) ?? []
        }
        set {
            defaults.set(dayStamp(), forKey: entriesDateKey)
            defaults.set(newValue, forKey: entriesKey)
        }
    }

    static var todayTotal: Int {
        todayEntries.reduce(0, +)
    }

    static var lastEntry: Int? {
        todayEntries.last
    }

    static func log(_ grams: Int) {
        guard grams > 0 else { return }
        todayEntries = todayEntries + [grams]
    }

    /// Removes the most recent entry logged today, if any.
    @discardableResult
    static func undoLastEntry() -> Int? {
        var entries = todayEntries
        guard let removed = entries.popLast() else { return nil }
        todayEntries = entries
        return removed
    }
}
