//
//  Theme.swift
//  PixelMark
//
//  Created by PixelMark on 11/22/25.
//

import SwiftUI
import Combine

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case cursorDark
    case light
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .cursorDark: return "Cursor Dark"
        case .light: return "Light"
        }
    }
    
    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .cursorDark: return "moon.circle.fill"
        case .light: return "sun.max.circle.fill"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .cursorDark: return .dark
        case .light: return .light
        }
    }
    
    var palette: ThemePalette {
        switch self {
        case .system:
            return ThemePalette(
                background: Color(nsColor: .windowBackgroundColor),
                sidebarBackground: Color(nsColor: .underPageBackgroundColor),
                sidebarHighlight: Color.accentColor.opacity(0.25),
                sidebarHover: Color.accentColor.opacity(0.15),
                cardBackground: Color(nsColor: .controlBackgroundColor),
                secondaryBackground: Color(nsColor: .controlBackgroundColor),
                accent: Color.accentColor,
                glow: Color.accentColor.opacity(0.55),
                textPrimary: Color.primary,
                textSecondary: Color.secondary
            )
        case .cursorDark:
            return ThemePalette(
                background: Color(hex: "#09090B"), // Deep black/gray
                sidebarBackground: Color(hex: "#000000"), // Pure black sidebar
                sidebarHighlight: Color(hex: "#1C1C1E"), // Subtle gray highlight
                sidebarHover: Color(hex: "#18181B"), // Slightly lighter hover
                cardBackground: Color(hex: "#09090B"), // Match background
                secondaryBackground: Color(hex: "#18181B"), // Input fields/wells
                accent: Color(hex: "#4ADE80"), // Vibrant green
                glow: Color(hex: "#4ADE80").opacity(0.2),
                textPrimary: Color(hex: "#EDEDED"), // Off-white
                textSecondary: Color(hex: "#A1A1AA") // Gray-400
            )
        case .light:
            return ThemePalette(
                background: Color.white,
                sidebarBackground: Color(red: 0.95, green: 0.96, blue: 0.98),
                sidebarHighlight: Color(red: 0.86, green: 0.90, blue: 0.98),
                sidebarHover: Color(red: 0.90, green: 0.93, blue: 0.99),
                cardBackground: Color.white,
                secondaryBackground: Color(red: 0.95, green: 0.96, blue: 0.98),
                accent: Color.accentColor,
                glow: Color.accentColor.opacity(0.4),
                textPrimary: Color.black,
                textSecondary: Color.black.opacity(0.6)
            )
        }
    }
}

struct ThemePalette {
    let background: Color
    let sidebarBackground: Color
    let sidebarHighlight: Color
    let sidebarHover: Color
    let cardBackground: Color
    let secondaryBackground: Color
    let accent: Color
    let glow: Color
    let textPrimary: Color
    let textSecondary: Color
}

@MainActor
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published private(set) var currentTheme: ThemePalette
    @Published private(set) var activeTheme: AppTheme
    
    private init() {
        let savedRaw = UserDefaults.standard.string(forKey: "appTheme") ?? AppTheme.system.rawValue
        let theme = AppTheme(rawValue: savedRaw) ?? .system
        self.currentTheme = theme.palette
        self.activeTheme = theme
    }
    
    func setTheme(_ theme: AppTheme) {
        guard theme != activeTheme else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            self.activeTheme = theme
            self.currentTheme = theme.palette
        }
        NotificationCenter.default.post(name: NSNotification.Name("ThemeDidChange"), object: nil)
    }
    
    var colorScheme: ColorScheme? {
        activeTheme.colorScheme
    }
}

struct ThemeColors {
    static var palette: ThemePalette { ThemeManager.shared.currentTheme }
    
    static var primaryBackground: Color { palette.background }
    static var sidebarBackground: Color { palette.sidebarBackground }
    static var sidebarHighlight: Color { palette.sidebarHighlight }
    static var sidebarHover: Color { palette.sidebarHover }
    static var cardBackground: Color { palette.cardBackground }
    static var secondaryBackground: Color { palette.secondaryBackground }
    static var accent: Color { palette.accent }
    static var glow: Color { palette.glow }
    static var textPrimary: Color { palette.textPrimary }
    static var textSecondary: Color { palette.textSecondary }
    
    static func cardBackground(for colorScheme: ColorScheme) -> Color {
        palette.cardBackground
    }
    
    static func sidebarBackground(for colorScheme: ColorScheme) -> Color {
        palette.sidebarBackground
    }
    
    static func sidebarHighlight(for colorScheme: ColorScheme) -> Color {
        palette.sidebarHighlight
    }
    
    static func sidebarHover(for colorScheme: ColorScheme) -> Color {
        palette.sidebarHover
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct FocusEffectDisabledModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content.focusEffectDisabled()
        } else {
            content.focusable(false)
        }
    }
}

extension View {
    func disableFocusEffect() -> some View {
        modifier(FocusEffectDisabledModifier())
    }
}
