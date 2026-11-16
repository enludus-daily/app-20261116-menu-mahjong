import Foundation

/// 面子（3 枚組）＝ 1 品の料理
struct Meld: Hashable, Sendable, Codable {
    enum Kind: Hashable, Sendable, Codable {
        /// 料理の役（Kitchen.recipes の番号）
        case recipe(Int)
        /// 同じ食材 3 枚（づくし）
        case triplet(Int)
    }

    let kind: Kind

    var tiles: [Int] {
        switch kind {
        case .recipe(let r): Kitchen.recipes[r].parts
        case .triplet(let k): [k, k, k]
        }
    }

    var recipe: Recipe? {
        if case .recipe(let r) = kind { return Kitchen.recipes[r] }
        return nil
    }

    var name: String {
        switch kind {
        case .recipe(let r): Kitchen.recipes[r].name
        case .triplet(let k): Kitchen.zukushiName(k)
        }
    }

    var cuisine: Cuisine? { recipe?.cuisine }
}

/// 4 面子 1 雀頭の分け方
struct Decomposition: Hashable, Sendable {
    let pair: Int
    let melds: [Meld]
}

/// 作りかけの手（そろった品・あと 1 枚の品）
struct Partial: Equatable, Sendable {
    var melds: [Meld] = []
    var pair: Int?
    /// あと 1 枚でできる料理と、足りない食材
    var nearly: [(recipe: Int, missing: Int)] = []

    static func == (a: Partial, b: Partial) -> Bool {
        a.melds == b.melds && a.pair == b.pair && a.nearly.map(\.recipe) == b.nearly.map(\.recipe) && a.nearly.map(\.missing) == b.nearly.map(\.missing)
    }
}

/// 和了りの判定・作りかけの手・捨てる牌の選び方。画面から切り離してテストする
enum Solver {
    /// 食材ごとの枚数
    static func counts(_ tiles: [Int]) -> [Int] {
        var c = Array(repeating: 0, count: Kitchen.kinds)
        for t in tiles { c[t] += 1 }
        return c
    }

    /// 料理を、いちばん小さい食材の番号ごとに分けておく
    static func byFirst(_ recipes: [Int]) -> [[Int]] {
        var table = Array(repeating: [Int](), count: Kitchen.kinds)
        for r in recipes { table[Kitchen.recipes[r].parts[0]].append(r) }
        return table
    }

    /// 14 枚の手の、4 面子 1 雀頭への分け方を全部
    static func decompositions(_ tiles: [Int], recipes: [Int]) -> [Decomposition] {
        guard tiles.count == 14 else { return [] }
        var c = counts(tiles)
        let table = byFirst(recipes)
        var found: [Decomposition] = []
        for p in 0..<Kitchen.kinds where c[p] >= 2 {
            c[p] -= 2
            var current: [Meld] = []
            collect(&c, &current, table) { found.append(Decomposition(pair: p, melds: $0)) }
            c[p] += 2
        }
        return found
    }

    static func isComplete(_ tiles: [Int], recipes: [Int]) -> Bool {
        !decompositions(tiles, recipes: recipes).isEmpty
    }

    private static func collect(_ c: inout [Int], _ current: inout [Meld], _ table: [[Int]], _ emit: ([Meld]) -> Void) {
        guard let i = c.firstIndex(where: { $0 > 0 }) else {
            if current.count == 4 { emit(current) }
            return
        }
        if c[i] >= 3 {
            c[i] -= 3
            current.append(Meld(kind: .triplet(i)))
            collect(&c, &current, table, emit)
            current.removeLast()
            c[i] += 3
        }
        for r in table[i] {
            let parts = Kitchen.recipes[r].parts
            guard parts.allSatisfy({ c[$0] > 0 }) else { continue }
            for x in parts { c[x] -= 1 }
            current.append(Meld(kind: .recipe(r)))
            collect(&c, &current, table, emit)
            current.removeLast()
            for x in parts { c[x] += 1 }
        }
    }

    /// 13 枚の手で、あと 1 枚で和了れる食材（テンパイの待ち）
    static func waits(_ tiles: [Int], recipes: [Int]) -> [Int] {
        guard tiles.count == 13 else { return [] }
        return (0..<Kitchen.kinds).filter { isComplete(tiles + [$0], recipes: recipes) }
    }

    /// 作りかけの手：そろった品をなるべく多く取り、残りから雀頭と「あと 1 枚の料理」を出す
    static func partial(_ tiles: [Int], recipes: [Int]) -> Partial {
        var c = counts(tiles)
        let table = byFirst(recipes)
        var best: [Meld] = []
        var current: [Meld] = []
        search(&c, from: 0, &current, &best, table)
        var rest = counts(tiles)
        for m in best { for t in m.tiles { rest[t] -= 1 } }
        var result = Partial(melds: best)
        // 雀頭は主食を先に
        let pairs = (0..<Kitchen.kinds).filter { rest[$0] >= 2 }
        result.pair = pairs.first(where: { Kitchen.ingredients[$0].isStaple }) ?? pairs.first
        if let p = result.pair { rest[p] -= 2 }
        var nearly: [(Int, Int)] = []
        for r in recipes {
            let parts = Kitchen.recipes[r].parts
            let missing = parts.filter { rest[$0] == 0 }
            if missing.count == 1 { nearly.append((r, missing[0])) }
        }
        result.nearly = nearly.map { (recipe: $0.0, missing: $0.1) }
        return result
    }

    private static func search(_ c: inout [Int], from: Int, _ current: inout [Meld], _ best: inout [Meld], _ table: [[Int]]) {
        if current.count > best.count { best = current }
        if best.count == 4 { return }
        guard let i = (from..<Kitchen.kinds).first(where: { c[$0] > 0 }) else { return }
        if c[i] >= 3 {
            c[i] -= 3
            current.append(Meld(kind: .triplet(i)))
            search(&c, from: i, &current, &best, table)
            current.removeLast()
            c[i] += 3
        }
        for r in table[i] {
            let parts = Kitchen.recipes[r].parts
            guard parts.allSatisfy({ c[$0] > 0 }) else { continue }
            for x in parts { c[x] -= 1 }
            current.append(Meld(kind: .recipe(r)))
            search(&c, from: i, &current, &best, table)
            current.removeLast()
            for x in parts { c[x] += 1 }
        }
        // この食材は面子に使わずに先へ
        search(&c, from: i + 1, &current, &best, table)
    }

    /// 牌の役立ち度（大きいほど残したい）。同じ食材の枚数と、一緒に料理になる食材があるか
    static func usefulness(of kind: Int, in tiles: [Int], recipes: [Int]) -> Int {
        let c = counts(tiles)
        var score = 4 * (c[kind] - 1)
        if Kitchen.ingredients[kind].isStaple && c[kind] >= 2 { score += 2 }
        for r in recipes {
            let parts = Kitchen.recipes[r].parts
            guard parts.contains(kind) else { continue }
            let others = parts.filter { $0 != kind && c[$0] > 0 }.count
            score += [0, 2, 6][others]
        }
        return score
    }

    /// おすすめの捨て牌（役立ち度がいちばん低い牌。同じなら番号の大きいほう）
    static func suggestedDiscard(_ tiles: [Int], recipes: [Int]) -> Int? {
        Set(tiles).min { a, b in
            let ua = usefulness(of: a, in: tiles, recipes: recipes)
            let ub = usefulness(of: b, in: tiles, recipes: recipes)
            return ua != ub ? ua < ub : a > b
        }
    }
}
