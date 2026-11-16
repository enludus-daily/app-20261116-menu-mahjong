import Foundation

/// 手全体の役（献立の形）
struct Yaku: Hashable, Sendable, Identifiable {
    let id: String
    let nameJa: String
    let nameEn: String
    let han: Int
    var yakuman = false

    var name: String { Lang.isJapanese ? nameJa : nameEn }
}

/// 和了りの結果（どう分けて、どの役で、何点か）
struct WinScore: Hashable, Sendable {
    let decomposition: Decomposition
    let yaku: [Yaku]
    let han: Int
    let points: Int
    var isYakuman: Bool { yaku.contains(where: \.yakuman) }
}

enum Scorer {
    /// 翻 → 点。符はない（やさしいルール）
    static func points(han: Int, yakuman: Bool) -> Int {
        if yakuman { return 32000 }
        switch han {
        case ...1: return 1000
        case 2: return 2000
        case 3: return 3900
        case 4: return 7700
        case 5: return 8000
        case 6...7: return 12000
        case 8...10: return 16000
        default: return 24000
        }
    }

    /// 点の呼び名（満貫など）
    static func rank(han: Int, yakuman: Bool) -> String? {
        if yakuman { return tr("役満", "Yakuman") }
        switch han {
        case 5: return tr("満貫", "Mangan")
        case 6...7: return tr("跳満", "Haneman")
        case 8...10: return tr("倍満", "Baiman")
        case 11...: return tr("三倍満", "Sanbaiman")
        default: return nil
        }
    }

    static func yaku(for d: Decomposition, selfDrawn: Bool) -> [Yaku] {
        let melds = d.melds
        let recipes = melds.compactMap(\.recipe)
        let triplets = melds.count - recipes.count
        // 役満：4 品すべてが同じ食材 3 枚（満漢全席）
        if triplets == 4 {
            return [Yaku(id: "manhan", nameJa: "満漢全席", nameEn: "Imperial Banquet", han: 13, yakuman: true)]
        }
        var list: [Yaku] = [Yaku(id: "agari", nameJa: "献立完成", nameEn: "Dinner's Ready", han: 1)]
        if selfDrawn { list.append(Yaku(id: "tsumo", nameJa: "自分で仕入れ（ツモ）", nameEn: "Self-Picked (Tsumo)", han: 1)) }
        if Kitchen.ingredients[d.pair].isStaple { list.append(Yaku(id: "staple", nameJa: "主食つき", nameEn: "With a Staple", han: 1)) }
        if recipes.contains(where: \.soup) { list.append(Yaku(id: "soup", nameJa: "汁物つき", nameEn: "With Soup", han: 1)) }
        if recipes.count == 4, let first = recipes.first?.cuisine, recipes.allSatisfy({ $0.cuisine == first }) {
            let names: [Cuisine: (String, String)] = [
                .wa: ("和定食", "Japanese Set Meal"), .chu: ("中華フルコース", "Chinese Full Course"),
                .yo: ("洋食プレート", "Western Plate"), .bento: ("お弁当箱", "Packed Bento Box"), .world: ("世界一周", "Around the World"),
            ]
            let n = names[first] ?? ("", "")
            list.append(Yaku(id: "same." + first.rawValue, nameJa: n.0, nameEn: n.1, han: 3))
        }
        let cuisines = Set(recipes.map(\.cuisine))
        if cuisines.isSuperset(of: [.wa, .chu, .yo]) {
            list.append(Yaku(id: "sangoku", nameJa: "和洋中そろい", nameEn: "East Meets West", han: 1))
        }
        let all = melds.flatMap(\.tiles) + [d.pair, d.pair]
        let cats = all.map { Kitchen.ingredients[$0].category }
        if !cats.contains(.meat) && !cats.contains(.sea) {
            list.append(Yaku(id: "veggie", nameJa: "野菜たっぷり", nameEn: "Garden Feast", han: 2))
        }
        if melds.allSatisfy({ $0.tiles.contains { Kitchen.ingredients[$0].category == .meat } }) {
            list.append(Yaku(id: "meat", nameJa: "肉祭り", nameEn: "Meat Festival", han: 2))
        }
        if melds.allSatisfy({ $0.tiles.contains { Kitchen.ingredients[$0].category == .sea } }) {
            list.append(Yaku(id: "sea", nameJa: "海の幸", nameEn: "Bounty of the Sea", han: 3))
        }
        if triplets > 0 {
            list.append(Yaku(id: "zukushi", nameJa: triplets == 1 ? "づくし" : "づくし×\(triplets)", nameEn: triplets == 1 ? "Single-Ingredient Dish" : "Single-Ingredient ×\(triplets)", han: triplets))
        }
        return list
    }

    static func score(_ d: Decomposition, selfDrawn: Bool) -> WinScore {
        let y = yaku(for: d, selfDrawn: selfDrawn)
        let yakuman = y.contains(where: \.yakuman)
        let han = y.reduce(0) { $0 + $1.han }
        return WinScore(decomposition: d, yaku: y, han: han, points: points(han: han, yakuman: yakuman))
    }

    /// いちばん点の高い分け方
    static func best(_ tiles: [Int], recipes: [Int], selfDrawn: Bool) -> WinScore? {
        Solver.decompositions(tiles, recipes: recipes)
            .map { score($0, selfDrawn: selfDrawn) }
            .max { a, b in a.points != b.points ? a.points < b.points : a.han < b.han }
    }
}
