/// The category icons, stored on a category by SF Symbol name.
nonisolated enum CategoryIcon: String, CaseIterable, Identifiable, Sendable {
    case cart
    case forkKnife = "fork.knife"
    case cup = "cup.and.saucer"
    case tram
    case car
    case airplane
    case house
    case bolt
    case iphone
    case repeatArrows = "repeat"
    case tshirt
    case heart
    case dumbbell
    case book
    case ticket
    case gift
    case wrench = "wrench.and.screwdriver"
    case tag

    var id: String { rawValue }

    /// Onboarding shows the first 12; the editor shows them all.
    static let onboarding = Array(allCases.prefix(12))

    var symbolName: String { rawValue }

    /// Unknown names (from a newer version) fall back to the tag.
    static func symbol(for name: String) -> String {
        (CategoryIcon(rawValue: name) ?? .tag).symbolName
    }

    var name: String {
        switch self {
        case .cart: "Shopping cart"
        case .forkKnife: "Fork and knife"
        case .cup: "Coffee cup"
        case .tram: "Tram"
        case .car: "Car"
        case .airplane: "Plane"
        case .house: "House"
        case .bolt: "Bolt"
        case .iphone: "Phone"
        case .repeatArrows: "Repeat"
        case .tshirt: "T-shirt"
        case .heart: "Heart"
        case .dumbbell: "Dumbbell"
        case .book: "Book"
        case .ticket: "Ticket"
        case .gift: "Gift"
        case .wrench: "Wrench"
        case .tag: "Tag"
        }
    }
}
