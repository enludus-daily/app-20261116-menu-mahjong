import Foundation

/// 和了って残った献立 1 つ
struct MenuRecord: Codable, Hashable, Sendable, Identifiable {
    var id: UUID = UUID()
    var date: Date
    /// 料理の役の id か、"zukushi.<食材の id>"
    var dishes: [String]
    /// 雀頭の食材の id
    var pair: String
    var points: Int
    var yaku: [String]
    var daily: Bool

    /// 面子から献立を作る
    init(date: Date, score: WinScore, daily: Bool) {
        self.date = date
        dishes = score.decomposition.melds.map { m in
            switch m.kind {
            case .recipe(let r): Kitchen.recipes[r].id
            case .triplet(let k): "zukushi." + Kitchen.ingredients[k].id
            }
        }
        pair = Kitchen.ingredients[score.decomposition.pair].id
        points = score.points
        yaku = score.yaku.map(\.name)
        self.daily = daily
    }

    var melds: [Meld] {
        dishes.compactMap { id in
            if id.hasPrefix("zukushi.") {
                let k = String(id.dropFirst("zukushi.".count))
                return Kitchen.ingredients.first { $0.id == k }.map { Meld(kind: .triplet($0.index)) }
            }
            return Kitchen.recipe(id: id).map { Meld(kind: .recipe($0.index)) }
        }
    }

    var pairKind: Int { Kitchen.ingredients.first { $0.id == pair }?.index ?? 25 }
}

/// 買い物メモの 1 行
struct ShoppingItem: Hashable, Sendable, Identifiable {
    let kind: Int
    /// その食材を使う品の数
    let uses: Int
    /// 冷蔵庫にある
    let inFridge: Bool
    var id: Int { kind }
}

enum Shopping {
    /// 献立に要る食材（同じ食材はまとめる。冷蔵庫にあるものは後ろ）
    static func list(melds: [Meld], pair: Int?, fridge: Set<Int> = []) -> [ShoppingItem] {
        var uses: [Int: Int] = [:]
        for m in melds { for k in Set(m.tiles) { uses[k, default: 0] += 1 } }
        if let pair { uses[pair, default: 0] += 1 }
        return uses.map { ShoppingItem(kind: $0.key, uses: $0.value, inFridge: fridge.contains($0.key)) }
            .sorted { a, b in
                if a.inFridge != b.inFridge { return !a.inFridge }
                let ca = Kitchen.ingredients[a.kind].category, cb = Kitchen.ingredients[b.kind].category
                let order = FoodGroup.allCases
                let ia = order.firstIndex(of: ca) ?? 0, ib = order.firstIndex(of: cb) ?? 0
                return ia != ib ? ia < ib : a.kind < b.kind
            }
    }
}

/// 積み上がる記録（端末の中だけ。UserDefaults に JSON で）
struct Progress: Codable, Equatable, Sendable {
    /// 献立帳（新しい順）
    var menus: [MenuRecord] = []
    /// 作った料理の役の id（図鑑）
    var collected: Set<String> = []
    /// 今日の一局を遊んだ日（yyyy-MM-dd）
    var dailyDays: Set<String> = []
    /// 今日の一局の結果（日 → 点。和了れなかったら 0）
    var dailyPoints: [String: Int] = [:]
    var wins = 0
    var games = 0
    /// 冷蔵庫にある食材の id
    var fridge: Set<String> = []
    /// 冷蔵庫モードのお試し（Pro でなくても 1 回）を使った
    var fridgeTrialUsed = false

    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// 今日の一局の種（日付から。だれが遊んでも同じ配牌）
    static func dailySeed(_ date: Date, calendar: Calendar = .current) -> UInt64 {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return UInt64((c.year ?? 2026) * 10000 + (c.month ?? 1) * 100 + (c.day ?? 1)) &* 2_654_435_761
    }

    func playedDaily(on date: Date, calendar: Calendar = .current) -> Bool {
        dailyDays.contains(Self.dayKey(date, calendar: calendar))
    }

    /// 連続日数：今日（まだなら昨日）からさかのぼって、今日の一局を遊んだ日が続いた数
    func streak(today: Date, calendar: Calendar = .current) -> Int {
        var day = calendar.startOfDay(for: today)
        if !dailyDays.contains(Self.dayKey(day, calendar: calendar)) {
            guard let y = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = y
        }
        var n = 0
        while dailyDays.contains(Self.dayKey(day, calendar: calendar)) {
            n += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return n
    }

    /// 和了りを記録する（献立帳・図鑑）
    mutating func recordWin(_ record: MenuRecord) {
        menus.insert(record, at: 0)
        for d in record.dishes where !d.hasPrefix("zukushi.") { collected.insert(d) }
        wins += 1
    }

    mutating func recordDaily(_ date: Date, points: Int, calendar: Calendar = .current) {
        let key = Self.dayKey(date, calendar: calendar)
        dailyDays.insert(key)
        dailyPoints[key] = max(dailyPoints[key] ?? 0, points)
    }

    /// その週（月曜はじまり）の 7 日と、その日のいちばん新しい献立
    func week(of date: Date, calendar: Calendar = .current) -> [(day: Date, menu: MenuRecord?)] {
        var cal = calendar
        cal.firstWeekday = 2
        let start = cal.dateInterval(of: .weekOfYear, for: date)?.start ?? cal.startOfDay(for: date)
        return (0..<7).map { i -> (day: Date, menu: MenuRecord?) in
            let day = cal.date(byAdding: .day, value: i, to: start) ?? start
            let menu = menus.first { cal.isDate($0.date, inSameDayAs: day) }
            return (day, menu)
        }
    }
}
