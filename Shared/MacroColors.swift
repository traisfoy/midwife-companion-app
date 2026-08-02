import SwiftUI

extension Macro {
    var ringColor: Color {
        switch self {
        case .protein: Color(hue: 0.58, saturation: 0.85, brightness: 0.95)
        case .carbs: Color(hue: 0.08, saturation: 0.85, brightness: 0.95)
        case .fat: Color(hue: 0.80, saturation: 0.65, brightness: 0.90)
        }
    }

    var goalHitColor: Color {
        Color(red: 0.20, green: 0.85, blue: 0.45)
    }

    func progressColor(for progress: Double) -> Color {
        if progress >= 1 { return goalHitColor }
        let t = min(max(progress, 0), 1)
        switch self {
        case .protein:
            return Color(hue: 0.58 - 0.45 * t, saturation: 0.85, brightness: 0.95)
        case .carbs:
            return Color(hue: 0.08 + 0.06 * t, saturation: 0.85 - 0.15 * t, brightness: 0.95)
        case .fat:
            return Color(hue: 0.80 - 0.10 * t, saturation: 0.65 + 0.10 * t, brightness: 0.90 + 0.05 * t)
        }
    }
}
