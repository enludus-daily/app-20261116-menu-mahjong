import SwiftUI

/// 町中華の夜の雀卓が世界。赤い漆と金の看板、緑の卓布、象牙の牌、伝票の紙。
/// 色・書体・形はここで決める（画面に色の 16 進を直に書かない）。
enum Theme {
    // 地：夜の店の暗い木（赤みの焦げ茶）
    static let night = Color(hex: 0x241210)
    static let nightRaised = Color(hex: 0x33191A)
    static let wood = Color(hex: 0x5A2A1C)
    static let woodLight = Color(hex: 0x7A3D27)

    // 看板の赤（漆）
    static let lacquer = Color(hex: 0xB0201C)
    static let lacquerDeep = Color(hex: 0x7E1311)
    static let lacquerSoft = Color(hex: 0xD9483B)

    // 金
    static let gold = Color(hex: 0xE5B651)
    static let goldDeep = Color(hex: 0xA97A22)
    static let goldSoft = Color(hex: 0xF4DFA3)

    // 卓布の緑
    static let felt = Color(hex: 0x1D5A42)
    static let feltDeep = Color(hex: 0x123D2C)
    static let feltLight = Color(hex: 0x2A7656)

    // 牌（象牙の面と、翡翠色の背）
    static let ivory = Color(hex: 0xF8F2E3)
    static let ivoryShade = Color(hex: 0xE2D6BC)
    static let jade = Color(hex: 0x2F8A63)
    static let jadeDeep = Color(hex: 0x1E5E43)

    // 伝票の紙
    static let slip = Color(hex: 0xFFFBF1)
    static let slipRule = Color(hex: 0xE07A6F)
    static let ink = Color(hex: 0x2B201C)
    static let inkSoft = Color(hex: 0x7A6A60)

    // 暗い地の上の文字
    static let cream = Color(hex: 0xF7EBD3)
    static let creamSoft = Color(hex: 0xCDB894)

    /// 牌に彫る字の色（食材の分類ごと。本物の麻雀牌の赤・緑・藍に寄せる）
    static func inkFor(_ c: FoodGroup) -> Color {
        switch c {
        case .meat: Color(hex: 0xC0322A)
        case .sea: Color(hex: 0x1E5BA6)
        case .veg: Color(hex: 0x2A7D3A)
        case .egg: Color(hex: 0xC8741C)
        case .staple: Color(hex: 0x8A6512)
        case .season: Color(hex: 0x4B3A8C)
        }
    }

    /// 料理の系統の札の色
    static func cuisine(_ c: Cuisine) -> Color {
        switch c {
        case .wa: Color(hex: 0x2A7D3A)
        case .chu: lacquer
        case .yo: Color(hex: 0x1E5BA6)
        case .bento: Color(hex: 0xC8741C)
        case .world: Color(hex: 0x4B3A8C)
        }
    }

    // 書体：看板の題字は太いゴシック、牌の字は彫ったような太い明朝、数字は丸い太字
    static func sign(_ size: CGFloat) -> Font { .system(size: size, weight: .black, design: .default) }
    static func carved(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .serif) }
    static func number(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .rounded).monospacedDigit() }
    static func label(_ style: Font.TextStyle = .subheadline, weight: Font.Weight = .semibold) -> Font { .system(style, design: .rounded).weight(weight) }

    // 角丸
    static let rTile: CGFloat = 0.14   // 牌の幅に対する割合
    static let rChip: CGFloat = 10
    static let rCard: CGFloat = 16
    static let rPanel: CGFloat = 22
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}
