import SwiftUI

enum Palette {
    static let void = Color(red: 0.055, green: 0.067, blue: 0.063)
    static let moss = Color(red: 0.090, green: 0.110, blue: 0.102)
    static let bark = Color(red: 0.133, green: 0.161, blue: 0.149)
    static let paper = Color(red: 0.910, green: 0.894, blue: 0.851)
    static let paperDim = Color(red: 0.910, green: 0.894, blue: 0.851).opacity(0.62)
    static let chartreuse = Color(red: 0.769, green: 0.949, blue: 0.353)
    static let celadon = Color(red: 0.478, green: 0.620, blue: 0.541)
    static let rust = Color(red: 0.820, green: 0.420, blue: 0.290)
}

enum Typeface {
    static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func numeric(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}
