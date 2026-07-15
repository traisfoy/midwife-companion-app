import AppIntents
import WidgetKit

/// Adds a fixed amount of protein to today's total. Driven by the +1/+5/+10
/// buttons on the widget (iOS 17 interactive widgets).
struct LogProteinIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Protein"
    static var description = IntentDescription("Adds grams of protein to today's total.")

    @Parameter(title: "Grams")
    var amount: Int

    init() {}

    init(amount: Int) {
        self.amount = amount
    }

    func perform() async throws -> some IntentResult {
        ProteinStore.log(amount)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// Removes the most recent logged entry. WidgetKit reserves press-and-hold on
/// widgets for the system edit menu, so subtraction is exposed through this
/// dedicated undo button instead of long-pressing the +N buttons.
struct UndoProteinIntent: AppIntent {
    static var title: LocalizedStringResource = "Undo Last Protein Entry"
    static var description = IntentDescription("Removes the most recent protein entry from today's total.")

    init() {}

    func perform() async throws -> some IntentResult {
        ProteinStore.undoLastEntry()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
