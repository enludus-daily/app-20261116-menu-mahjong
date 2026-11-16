import Foundation

/// 食材の分類（牌に彫る字の色が変わる）
enum FoodGroup: String, Sendable, CaseIterable {
    case meat, sea, veg, egg, staple, season
}

/// 料理の系統（同じ系統で 4 品そろうと役になる）
enum Cuisine: String, Sendable, CaseIterable, Codable {
    case wa, chu, yo, bento, world

    var name: String {
        switch self {
        case .wa: tr("和食", "Japanese")
        case .chu: tr("中華", "Chinese")
        case .yo: tr("洋食", "Western")
        case .bento: tr("お弁当", "Bento")
        case .world: tr("世界の料理", "World")
        }
    }

    /// 札に出す 1 文字
    var mark: String {
        switch self {
        case .wa: "和"
        case .chu: "中"
        case .yo: "洋"
        case .bento: "弁"
        case .world: "世"
        }
    }
}

/// 食材の牌の種類（31 種。1 種につき 4 枚）
struct Ingredient: Sendable, Hashable, Identifiable {
    let index: Int
    let id: String
    /// 牌に彫る字
    let glyph: String
    let nameJa: String
    let nameEn: String
    let category: FoodGroup

    var name: String { Lang.isJapanese ? nameJa : nameEn }
    var isStaple: Bool { category == .staple }
}

/// 料理の役（3 種の食材の組み合わせ）
struct Recipe: Sendable, Hashable, Identifiable {
    let index: Int
    let id: String
    let nameJa: String
    let nameEn: String
    let cuisine: Cuisine
    /// 食材の番号（小さい順）
    let parts: [Int]
    let soup: Bool
    /// Pro の追加の役（お弁当・世界の料理）
    let pro: Bool
    let howJa: String
    let howEn: String

    var name: String { Lang.isJapanese ? nameJa : nameEn }
    var how: String { Lang.isJapanese ? howJa : howEn }
}

enum Kitchen {
    static var kinds: Int { ingredients.count }

    static func ingredient(_ index: Int) -> Ingredient { ingredients[index] }

    static func recipe(id: String) -> Recipe? { recipes.first { $0.id == id } }

    /// 遊べる役（Pro なら追加の役も）
    static func recipeIndices(pro: Bool) -> [Int] {
        recipes.filter { pro || !$0.pro }.map(\.index)
    }

    /// 同じ食材 3 枚の「づくし」の名前
    static func zukushiName(_ kind: Int) -> String {
        let i = ingredients[kind]
        return Lang.isJapanese ? i.nameJa + "づくし" : "All-" + i.nameEn + " Plate"
    }

    /// 雀頭（同じ食材 2 枚）の名前。主食なら主食、ほかは小鉢
    static func pairName(_ kind: Int) -> String {
        let i = ingredients[kind]
        if i.isStaple {
            switch i.id {
            case "rice": return tr("白ごはん", "Steamed rice")
            case "noodle": return tr("ざる麺", "Chilled noodles")
            default: return tr("焼きたてパン", "Fresh bread")
            }
        }
        return Lang.isJapanese ? i.nameJa + "の小鉢" : "Side of " + i.nameEn.lowercased()
    }
}
