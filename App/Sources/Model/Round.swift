import Foundation

/// 決まった種から同じ並びを作る乱数（今日の一局は、だれが遊んでも同じ配牌になる）
struct SplitMix64: RandomNumberGenerator, Sendable, Equatable {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// 相手の料理人（決まった打ち方の CPU）
struct Rival: Sendable, Equatable {
    let glyph: String
    let nameJa: String
    let nameEn: String
    var name: String { Lang.isJapanese ? nameJa : nameEn }

    static let all: [Rival] = [
        Rival(glyph: "点", nameJa: "点心の陳さん", nameEn: "Chen, dim sum chef"),
        Rival(glyph: "洋", nameJa: "洋食の森さん", nameEn: "Mori, bistro cook"),
        Rival(glyph: "和", nameJa: "割烹の梅さん", nameEn: "Ume, kappo chef"),
    ]
}

enum Outcome: Equatable, Sendable {
    /// 自分の和了り（ツモ＝自分で引いた / ロン＝相手の捨て牌）
    case youWin(selfDrawn: Bool, from: Int?)
    case rivalWin(Int)
    /// 牌がなくなった（流局）
    case exhausted
}

enum Phase: Equatable, Sendable {
    /// 自分の番：1 枚捨てる（ツモ和了りもできる）
    case yourTurn
    /// 相手の番
    case rivals
    /// 相手の捨て牌で和了れる
    case ronChance(from: Int, tile: Int)
    case over(Outcome)
}

/// 1 局の状態。画面から切り離し、決まった手順で進める（テストできる形）
struct Round: Sendable, Equatable {
    /// 山（後ろから引く）
    var wall: [Int]
    /// 4 人の手（0 が自分）
    var hands: [[Int]]
    /// 4 人の捨て牌
    var rivers: [[Int]]
    var turn = 0
    var phase: Phase = .yourTurn
    /// いま引いた牌（右に離して置く）
    var drawn: Int?
    let recipes: [Int]
    /// 相手の打ち方のゆるさ（0 は最善手、1 は全部でたらめ）
    let careless: Double
    var rng: SplitMix64
    /// 終わったときの和了りの手（自分か相手）
    var winningHand: [Int]?

    static let handSize = 13

    /// 新しい局。冷蔵庫モードでは、冷蔵庫にある食材の牌が 6 枚ずつになる
    init(seed: UInt64, recipes: [Int], careless: Double = 0.5, fridge: Set<Int> = []) {
        var rng = SplitMix64(seed: seed)
        var wall: [Int] = []
        for k in 0..<Kitchen.kinds {
            wall += Array(repeating: k, count: fridge.contains(k) ? 6 : 4)
        }
        wall.shuffle(using: &rng)
        var hands = Array(repeating: [Int](), count: 4)
        for p in 0..<4 {
            for _ in 0..<Self.handSize { hands[p].append(wall.removeLast()) }
        }
        self.wall = wall
        self.hands = hands
        self.rivers = Array(repeating: [], count: 4)
        self.recipes = recipes
        self.careless = careless
        self.rng = rng
        drawForYou()
    }

    /// 見本・デモ用：自分の手と山の順を決めて始める（山は先頭から引く順に並べる）
    init(yourHand: [Int], draws: [Int], rivalHands: [[Int]], recipes: [Int]) {
        wall = Array(draws.reversed())
        hands = [yourHand] + rivalHands
        rivers = Array(repeating: [], count: 4)
        self.recipes = recipes
        careless = 1
        rng = SplitMix64(seed: 7)
        drawForYou()
    }

    var yourHand: [Int] { hands[0] }
    var wallCount: Int { wall.count }
    var isOver: Bool { if case .over = phase { return true } else { return false } }

    /// 自分の手を並べた形（引いた牌は右端）
    var displayHand: [Int] {
        var rest = hands[0]
        if let d = drawn, let i = rest.firstIndex(of: d) { rest.remove(at: i) }
        rest.sort()
        if let d = drawn, hands[0].contains(d) { rest.append(d) }
        return rest
    }

    var canTsumo: Bool { phase == .yourTurn && Solver.isComplete(hands[0], recipes: recipes) }

    private mutating func drawForYou() {
        guard let t = wall.popLast() else {
            phase = .over(.exhausted)
            drawn = nil
            return
        }
        hands[0].append(t)
        drawn = t
        turn = 0
        phase = .yourTurn
    }

    /// 自分が 1 枚捨てる
    mutating func discard(_ kind: Int) {
        guard phase == .yourTurn, let i = hands[0].firstIndex(of: kind) else { return }
        hands[0].remove(at: i)
        rivers[0].append(kind)
        drawn = nil
        turn = 1
        phase = .rivals
    }

    /// 相手 1 人ぶん進める（引く → 和了りか捨てる）
    mutating func rivalStep() {
        guard phase == .rivals else { return }
        let p = turn
        guard let t = wall.popLast() else {
            phase = .over(.exhausted)
            return
        }
        hands[p].append(t)
        if Solver.isComplete(hands[p], recipes: recipes) {
            winningHand = hands[p]
            phase = .over(.rivalWin(p))
            return
        }
        let d: Int
        if Double.random(in: 0..<1, using: &rng) < careless {
            d = hands[p].randomElement(using: &rng) ?? t
        } else {
            d = Solver.suggestedDiscard(hands[p], recipes: recipes) ?? t
        }
        if let i = hands[p].firstIndex(of: d) { hands[p].remove(at: i) }
        rivers[p].append(d)
        if Solver.isComplete(hands[0] + [d], recipes: recipes) {
            phase = .ronChance(from: p, tile: d)
            return
        }
        advance()
    }

    private mutating func advance() {
        if turn == 3 {
            drawForYou()
        } else {
            turn += 1
            phase = .rivals
        }
    }

    /// 相手の捨て牌で和了る
    mutating func ron() {
        guard case .ronChance(let from, let tile) = phase else { return }
        hands[0].append(tile)
        if let i = rivers[from].lastIndex(of: tile) { rivers[from].remove(at: i) }
        winningHand = hands[0]
        drawn = tile
        phase = .over(.youWin(selfDrawn: false, from: from))
    }

    /// 和了らずに見送る
    mutating func passRon() {
        guard case .ronChance = phase else { return }
        phase = .rivals
        advance()
    }

    /// 自分で引いて和了る
    mutating func tsumo() {
        guard canTsumo else { return }
        winningHand = hands[0]
        phase = .over(.youWin(selfDrawn: true, from: nil))
    }

    /// 自分の和了りの点
    var yourScore: WinScore? {
        guard case .over(.youWin(let selfDrawn, _)) = phase, let hand = winningHand else { return nil }
        return Scorer.best(hand, recipes: recipes, selfDrawn: selfDrawn)
    }

    /// 相手の和了りの点
    var rivalScore: WinScore? {
        guard case .over(.rivalWin) = phase, let hand = winningHand else { return nil }
        return Scorer.best(hand, recipes: recipes, selfDrawn: true)
    }
}
