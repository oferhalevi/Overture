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

        // Calculate contrast ratios for both white and black text
        let whiteContrast = ArtworkColors.contrastRatio(l1: primaryLuminance, l2: 1.0)
        let blackContrast = ArtworkColors.contrastRatio(l1: primaryLuminance, l2: 0.0)

        // Pick whichever has better contrast
        // WCAG AA requires 4.5:1 for normal text, 3:1 for large text
        let useWhiteText = whiteContrast >= blackContrast

        self.isDark = useWhiteText

        if useWhiteText {
            // Check if we need to boost contrast for mid-tone backgrounds
            if whiteContrast < 4.5 {
                // Mid-tone background - use pure white with higher opacity for secondary
                self.textColor = .white
                self.textColorSecondary = Color.white.opacity(0.9)
            } else {
                self.textColor = .white
                self.textColorSecondary = Color.white.opacity(0.75)
            }
            self.cardBackground = Color.white.opacity(0.08)
        } else {
            // Check if we need to boost contrast for mid-tone backgrounds
            if blackContrast < 4.5 {
                // Mid-tone background - use pure black
                self.textColor = .black
                self.textColorSecondary = Color.black.opacity(0.85)
            } else {
                self.textColor = Color(red: 0.05, green: 0.05, blue: 0.05)
                self.textColorSecondary = Color(red: 0.05, green: 0.05, blue: 0.05).opacity(0.7)
            }
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
