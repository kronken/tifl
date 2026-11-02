import SwiftUI

/// Type styles from the design system. The design's sizes match the iOS text
/// styles, so these scale with Dynamic Type.
extension Font {
    /// 34/41 bold. Screen titles.
    static let screenTitle = Font.largeTitle.bold()
    /// 22/28 bold. Section headings inside cards .
    static let cardTitle = Font.title2.bold()
    /// 17/22 semibold. Row titles, buttons.
    static let rowTitle = Font.headline
    /// 15/20. Secondary row text.
    static let rowDetail = Font.subheadline
    /// 12/16 medium. Uppercase section labels, small meta.
    static let label = Font.caption.weight(.medium)

    /// SF Rounded with tabular digits, for amounts and counts.
    static func number(_ style: Font.TextStyle = .title2, weight: Font.Weight = .semibold) -> Font {
        .system(style, design: .rounded, weight: weight).monospacedDigit()
    }
}
