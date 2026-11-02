import SwiftUI

/// The eight category colours. Stored on a category by raw value.
nonisolated enum CategoryColor: String, CaseIterable, Identifiable, Sendable {
    case brass, denim, teal, clay, violet, moss, rose, steel

    var id: String { rawValue }

    /// Unknown keys (from a newer version) fall back to steel.
    init(key: String) {
        self = CategoryColor(rawValue: key) ?? .steel
    }

    var color: Color {
        switch self {
        case .brass: Color(hex: 0xD6AD66)
        case .denim: Color(hex: 0x7D9CF0)
        case .teal: Color(hex: 0x4FC1B0)
        case .clay: Color(hex: 0xE0896A)
        case .violet: Color(hex: 0xB392F0)
        case .moss: Color(hex: 0x93C46B)
        case .rose: Color(hex: 0xEF8FB0)
        case .steel: Color(hex: 0x9AA4B1)
        }
    }

    var name: String { rawValue.capitalized }

    /// The colour after this one, used to start the next new category.
    var next: CategoryColor {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }
}
