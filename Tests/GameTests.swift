import Foundation
import Testing
@testable import MenuMahjong

private func k(_ id: String) -> Int { Kitchen.ingredients.first { $0.id == id }!.index }
private let base = Kitchen.recipeIndices(pro: false)
private let all = Kitchen.recipeIndices(pro: true)

struct KitchenDataTests {
    @Test func hasEnoughHandMadeDishes() {
        #expect(Kitchen.ingredients.count == 31)
        #expect(base.count >= 70)
        #expect(all.count - base.count == 32)
    }

    @Test func everyDishHasThreeDifferentIngredientsInOrder() {
        for r in Kitchen.recipes {
            #expect(Set(r.parts).count == 3, "\(r.id)")
            #expect(r.parts == r.parts.sorted(), "\(r.id)")
            #expect(!r.nameEn.isEmpty && !r.howEn.isEmpty && !r.howJa.isEmpty, "\(r.id)")
        }
    }

    @Test func noTwoDishesShareTheSameIngredients() {
        let sets = Kitchen.recipes.map { Set($0.parts) }
        #expect(Set(sets).count == sets.count)
    }
}

struct SolverTests {
    /// 生姜焼き・親子丼・麻婆豆腐・ミネストローネ＋ご飯 2 枚
    let winning = ["pork", "ginger", "soy", "chicken", "egg", "onion", "mince", "tofu", "garlic", "tomato", "cabbage", "onion", "rice", "rice"].map(k)

    @Test func fourDishesAndAPairWin() {
        #expect(Solver.isComplete(winning, recipes: base))
    }

    @Test func handWithoutAPairDoesNotWin() {
        var hand = winning
        hand[hand.count - 1] = k("bread")
        #expect(!Solver.isComplete(hand, recipes: base))
    }

    @Test func thirteenTilesNeverWin() {
        #expect(!Solver.isComplete(Array(winning.dropLast()), recipes: base))
    }

    @Test func threeOfAKindIsADish() {
        let hand = ["chicken", "chicken", "chicken", "pork", "pork", "pork", "beef", "beef", "beef", "egg", "egg", "egg", "rice", "rice"].map(k)
        #expect(Solver.isComplete(hand, recipes: base))
    }

    @Test func waitsListTheMissingTile() {
        let thirteen = Array(winning.dropLast())
        #expect(Solver.waits(thirteen, recipes: base).contains(k("rice")))
        #expect(!Solver.waits(thirteen, recipes: base).contains(k("salmon")))
    }

    @Test func proDishesOnlyCountWithPro() {
        // から揚げ（鶏・にんにく・生姜）は Pro の役
        let hand = ["chicken", "garlic", "ginger", "pork", "ginger", "soy", "mince", "tofu", "garlic", "tomato", "cabbage", "onion", "rice", "rice"].map(k)
        #expect(!Solver.isComplete(hand, recipes: base))
        #expect(Solver.isComplete(hand, recipes: all))
    }

    @Test func partialFindsFinishedDishesAndNearOnes() {
        let hand = ["pork", "ginger", "soy", "chicken", "egg", "rice", "rice", "salmon", "clam", "mackerel", "cucumber", "pepper", "spinach"].map(k)
        let p = Solver.partial(hand, recipes: base)
        #expect(p.melds == [Meld(kind: .recipe(0))])
        #expect(p.pair == k("rice"))
        #expect(p.nearly.contains { Kitchen.recipes[$0.recipe].id == "oyakodon" && $0.missing == k("onion") })
    }

    @Test func suggestedDiscardKeepsFinishedDishes() {
        let hand = ["pork", "ginger", "soy", "chicken", "egg", "onion", "mince", "tofu", "garlic", "tomato", "cabbage", "rice", "rice", "mackerel"].map(k)
        let d = Solver.suggestedDiscard(hand, recipes: base)
        #expect(d != nil)
        #expect(![k("pork"), k("ginger"), k("soy"), k("rice")].contains(d!))
    }
}

struct ScorerTests {
    @Test func sampleMenuScoresWithStapleSoupAndAllThreeCuisines() {
        let d = Decomposition(pair: k("rice"), melds: [0, 2, 29, 56].map { Meld(kind: .recipe($0)) })
        let s = Scorer.score(d, selfDrawn: true)
        let ids = Set(s.yaku.map(\.id))
        #expect(ids.isSuperset(of: ["agari", "tsumo", "staple", "soup", "sangoku"]))
        #expect(s.han == 5)
        #expect(s.points == 8000)
    }

    @Test func fourTripletsIsTheImperialBanquet() {
        let d = Decomposition(pair: k("rice"), melds: ["chicken", "pork", "beef", "egg"].map { Meld(kind: .triplet(k($0))) })
        let s = Scorer.score(d, selfDrawn: false)
        #expect(s.isYakuman)
        #expect(s.points == 32000)
    }

    @Test func sameCuisineForAllFourDishes() {
        // 和食 4 品：生姜焼き・肉じゃが・豆腐とねぎの味噌汁・ほうれん草ときのこのおひたし
        let d = Decomposition(pair: k("noodle"), melds: [0, 1, 5, 6].map { Meld(kind: .recipe($0)) })
        let s = Scorer.score(d, selfDrawn: false)
        #expect(s.yaku.contains { $0.id == "same.wa" })
    }

    @Test func pointsGrowWithHan() {
        let values = (1...12).map { Scorer.points(han: $0, yakuman: false) }
        #expect(values == values.sorted())
        #expect(Scorer.points(han: 1, yakuman: true) == 32000)
    }

    @Test func bestPicksTheHighestScoringSplit() {
        let hand = ["chicken", "chicken", "chicken", "pork", "pork", "pork", "beef", "beef", "beef", "egg", "egg", "egg", "rice", "rice"].map(k)
        let best = Scorer.best(hand, recipes: base, selfDrawn: true)
        #expect(best?.isYakuman == true)
    }
}

struct RoundTests {
    @Test func dealGivesThirteenEachAndYouDrawFirst() {
        let r = Round(seed: 42, recipes: base)
        #expect(r.hands[0].count == 14)
        #expect(r.hands[1...].allSatisfy { $0.count == 13 })
        #expect(r.wallCount == 31 * 4 - 13 * 4 - 1)
        #expect(r.phase == .yourTurn)
    }

    @Test func sameSeedSameDeal() {
        #expect(Round(seed: 20261116, recipes: base) == Round(seed: 20261116, recipes: base))
        #expect(Round(seed: 1, recipes: base).hands != Round(seed: 2, recipes: base).hands)
    }

    @Test func fridgeIngredientsGetSixTiles() {
        let r = Round(seed: 3, recipes: base, fridge: [k("egg")])
        let total = r.wall + r.hands.flatMap { $0 }
        #expect(total.filter { $0 == k("egg") }.count == 6)
        #expect(total.filter { $0 == k("pork") }.count == 4)
    }

    @Test func discardPassesTheTurnAndRivalsComeBack() {
        var r = Round(seed: 9, recipes: base)
        let tile = r.yourHand[0]
        r.discard(tile)
        #expect(r.phase == .rivals && r.turn == 1)
        #expect(r.rivers[0] == [tile])
        var steps = 0
        while r.phase == .rivals && steps < 10 { r.rivalStep(); steps += 1 }
        if r.phase == .yourTurn { #expect(r.yourHand.count == 14) }
    }

    @Test func sampleRoundWinsOnTheThirdDraw() {
        var r = Samples.round()
        #expect(!r.canTsumo)
        r.discard(k("eggplant"))
        while r.phase == .rivals { r.rivalStep() }
        #expect(r.phase == .yourTurn)
        #expect(r.drawn == k("onion"))
        r.discard(k("bread"))
        while r.phase == .rivals { r.rivalStep() }
        #expect(r.drawn == k("rice"))
        #expect(r.canTsumo)
        r.tsumo()
        #expect(r.phase == .over(.youWin(selfDrawn: true, from: nil)))
        #expect(r.yourScore?.points == 8000)
    }

    @Test func ronTakesTheRivalDiscard() {
        var r = Samples.round()
        r.discard(k("eggplant"))
        while r.phase == .rivals { r.rivalStep() }
        r.discard(k("bread"))
        r.phase = .ronChance(from: 1, tile: k("rice"))
        r.ron()
        #expect(r.phase == .over(.youWin(selfDrawn: false, from: 1)))
        #expect(r.yourScore != nil)
    }

    @Test func gamesAlwaysEnd() {
        for seed in UInt64(1)...30 {
            let r = Launch.playOut(seed: seed)
            #expect(r.isOver)
        }
    }
}

struct ProgressTests {
    let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return c
    }()

    private func day(_ d: Int) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 11, day: d, hour: 19))!
    }

    @Test func streakCountsBackFromTodayOrYesterday() {
        var p = Progress()
        for d in [13, 14, 15] { p.recordDaily(day(d), points: 0, calendar: cal) }
        #expect(p.streak(today: day(15), calendar: cal) == 3)
        // 今日まだでも、昨日までの連続は消えない
        #expect(p.streak(today: day(16), calendar: cal) == 3)
        // 2 日あくと途切れる
        #expect(p.streak(today: day(17), calendar: cal) == 0)
    }

    @Test func dailySeedIsTheSameForTheSameDay() {
        #expect(Progress.dailySeed(day(16), calendar: cal) == Progress.dailySeed(day(16).addingTimeInterval(3600), calendar: cal))
        #expect(Progress.dailySeed(day(16), calendar: cal) != Progress.dailySeed(day(17), calendar: cal))
    }

    @Test func winFillsMenuBookAndCollection() {
        var p = Progress()
        let d = Decomposition(pair: k("rice"), melds: [0, 2, 29].map { Meld(kind: .recipe($0)) } + [Meld(kind: .triplet(k("egg")))])
        let record = MenuRecord(date: day(16), score: Scorer.score(d, selfDrawn: true), daily: true)
        p.recordWin(record)
        #expect(p.menus.count == 1)
        #expect(p.collected == ["shogayaki", "oyakodon", "mapotofu"])
        #expect(p.menus[0].melds.count == 4)
        #expect(p.menus[0].pairKind == k("rice"))
    }

    @Test func progressSurvivesJSON() throws {
        var p = Progress()
        p.fridge = ["egg"]
        p.recordDaily(day(16), points: 8000, calendar: cal)
        let data = try JSONEncoder().encode(p)
        #expect(try JSONDecoder().decode(Progress.self, from: data) == p)
    }

    @Test func shoppingListPutsFridgeItemsLast() {
        let melds = [0, 2].map { Meld(kind: .recipe($0)) }
        let list = Shopping.list(melds: melds, pair: k("rice"), fridge: [k("egg")])
        #expect(list.last?.kind == k("egg"))
        #expect(list.contains { $0.kind == k("rice") })
        #expect(list.count == 7)
    }

    @Test func weekHasSevenDaysStartingMonday() {
        let p = Progress()
        let week = p.week(of: day(18), calendar: cal)
        #expect(week.count == 7)
        #expect(cal.component(.weekday, from: week[0].day) == 2)
    }
}

@MainActor
struct AppModelTests {
    @Test func startingTodaysHandOpensATable() {
        let model = AppModel(persists: false)
        model.useSample = true
        model.start(.daily)
        #expect(model.round != nil)
        #expect(model.mode == .daily)
        #expect(model.round?.phase == .yourTurn)
    }

    @Test func tappingTheSameTileTwiceDiscardsIt() {
        let model = AppModel(persists: false)
        model.still = true
        model.useSample = true
        model.start(.daily)
        let eggplant = Kitchen.ingredients.first { $0.id == "eggplant" }!.index
        model.tap(eggplant)
        #expect(model.selected == eggplant)
        model.tap(eggplant)
        #expect(model.round?.rivers[0] == [eggplant])
        #expect(model.selected == nil)
    }

    @Test func fridgeModeWithoutIngredientsOpensTheFridge() {
        let model = AppModel(persists: false)
        model.start(.fridge)
        #expect(model.round == nil)
        #expect(model.activeSheet == .fridge)
    }
}
