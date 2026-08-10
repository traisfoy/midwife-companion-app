import AppIntents
import WidgetKit

struct LogMacroIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Macro"
    static var description = IntentDescription("Adds grams to today's total for the currently selected macro.")

    @Parameter(title: "Grams")
    var amount: Int

    init() {}

    init(amount: Int) {
        self.amount = amount
    }

    func perform() async throws -> some IntentResult {
        MacroStore.log(amount, for: MacroStore.selectedMacro)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct UndoMacroIntent: AppIntent {
    static var title: LocalizedStringResource = "Undo Last Macro Entry"
    static var description = IntentDescription("Removes the most recent entry for the currently selected macro.")

    init() {}

    func perform() async throws -> some IntentResult {
        MacroStore.undoLastEntry(for: MacroStore.selectedMacro)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct SwitchMacroIntent: AppIntent {
    static var title: LocalizedStringResource = "Switch Macro"
    static var description = IntentDescription("Cycles the widget between protein, carbs, and fat.")

    init() {}

    func perform() async throws -> some IntentResult {
        // Carbs/fat tracking requires the one-time unlock; stay on protein until then.
        guard MacroStore.fullMacrosUnlocked else { return .result() }
        MacroStore.selectedMacro = MacroStore.selectedMacro.next
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// Keep old names so existing widget installs don't break
typealias LogProteinIntent = LogMacroIntent
typealias UndoProteinIntent = UndoMacroIntent
