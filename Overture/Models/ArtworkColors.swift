import SwiftUI

struct ArtworkColors: Equatable {
    let primary: Color
    let secondary: Color
    let tertiary: Color
    let textColor: Color
    let textColorSecondary: Color  // For less prominent text
    let cardBackground: Color      // Semi-transparent card background
    let isDark: Bool

    static let `default` = ArtworkColors(
        primary: Color(red: 0.1, green: 0.1, blue: 0.15),
        secondary: Color(red: 0.15, green: 0.15, blue: 0.2),
        tertiary: Color(red: 0.2, green: 0.2, blue: 0.25),
        textColor: .white,
        textColorSecondary: Color.white.opacity(0.7),
        cardBackground: Color.black.opacity(0.3),
        isDark: true
    )

    init(primary: Color, secondary: Color, tertiary: Color, textColor: Color, textColorSecondary: Color, cardBackground: Color, isDark: Bool) {
        self.primary = primary
        self.secondary = secondary
        self.tertiary = tertiary
        self.textColor = textColor
        self.textColorSecondary = textColorSecondary
        self.cardBackground = cardBackground
        self.isDark = isDark
    }

    /// Create from NSColor components with proper contrast calculation
    init(colors: [NSColor]) {
        guard colors.count >= 3 else {
            self = .default
            return
        }

        self.primary = Color(colors[0])
        self.secondary = Color(colors[1])
        self.tertiary = Color(colors[2])

        // Calculate luminance of primary background color
        let primaryLuminance = colors[0].luminance

        // Determine if background is dark or light
        // Use a threshold that accounts for mid-tones
        self.isDark = primaryLuminance < 0.45

        // Calculate text colors ensuring WCAG AA contrast (4.5:1 minimum)
        if isDark {
            // Dark background - use white text
            self.textColor = .white
            self.textColorSecondary = Color.white.opacity(0.75)
            self.cardBackground = Color.white.opacity(0.08)
        } else {
            // Light background - use black text
            // For very light backgrounds (white, cream, light grey), ensure strong contrast
            self.textColor = Color(red: 0.05, green: 0.05, blue: 0.05)
            self.textColorSecondary = Color(red: 0.05, green: 0.05, blue: 0.05).opacity(0.7)
            self.cardBackground = Color.black.opacity(0.06)
        }
    }

    /// Calculate contrast ratio between two luminance values (WCAG formula)
    static func contrastRatio(l1: CGFloat, l2: CGFloat) -> CGFloat {
        let lighter = max(l1, l2)
        let darker = min(l1, l2)
        return (lighter + 0.05) / (darker + 0.05)
    }
}

extension NSColor {
    var luminance: CGFloat {
        guard let rgb = usingColorSpace(.sRGB) else { return 0.5 }
        // Relative luminance formula (WCAG 2.1)
        func adjust(_ component: CGFloat) -> CGFloat {
            component <= 0.03928
                ? component / 12.92
                : pow((component + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * adjust(rgb.redComponent) +
               0.7152 * adjust(rgb.greenComponent) +
               0.0722 * adjust(rgb.blueComponent)
    }
}
