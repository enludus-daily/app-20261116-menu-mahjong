import SwiftUI

@main
struct MenuMahjongApp: App {
    /// アプリ全体で 1 つだけ。App の init は何度も呼ばれることがあるので、ここで作り直さない
    /// （作り直すと、UI テストの起動で記録を消す処理も繰り返し、画面とボタンが別のモデルを見てしまう）
    private let model = Launch.shared

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
        }
    }
}

struct RootView: View {
    let model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var model = model
        let _ = print("[MM] root body model=\(ObjectIdentifier(model).hashValue) round=\(model.round == nil ? "nil" : "set") onboarded=\(model.onboarded)")
        ZStack {
            if model.onboarded {
                HomeView()
                    .accessibilityHidden(model.round != nil || model.activeSheet != nil)
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
            // 卓と結果は、ホームの上に重ねる層（全画面の表示の仕組みは使わない）
            if model.round != nil {
                ZStack {
                    if model.showResult {
                        ResultView().transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        TableView().transition(.opacity)
                    }
                }
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: model.showResult)
                .accessibilityHidden(model.activeSheet != nil)
                .transition(.move(edge: .bottom))
                .zIndex(1)
            }
        }
        .animation(.easeOut(duration: 0.35), value: model.onboarded)
        .animation(.spring(response: 0.42, dampingFraction: 0.9), value: model.round == nil)
        .environment(model)
        // 夜の町中華の雀卓が世界。看板の灯りと卓布の緑が主役なので、画面はダークに固定する
        .preferredColorScheme(.dark)
        .sheet(item: $model.activeSheet) { sheet in
            SheetContent(sheet: sheet).environment(model).environment(\.locale, Lang.locale).preferredColorScheme(.dark)
        }
        // 手応えの表（README）：押す・捨てる・品がそろう・ロンの機会・和了り・和了られた
        .sensoryFeedback(trigger: model.pressTick) { _, _ in model.hapticsOn ? .selection : nil }
        .sensoryFeedback(trigger: model.discardTick) { _, _ in model.hapticsOn ? .impact(weight: .light) : nil }
        .sensoryFeedback(trigger: model.meldTick) { _, _ in model.hapticsOn ? .impact(weight: .medium) : nil }
        .sensoryFeedback(trigger: model.ronTick) { _, _ in model.hapticsOn ? .warning : nil }
        .sensoryFeedback(trigger: model.winTick) { _, _ in model.hapticsOn ? .success : nil }
        .sensoryFeedback(trigger: model.loseTick) { _, _ in model.hapticsOn ? .error : nil }
        .task { await Launch.run(model) }
        .task { await model.purchases.load() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && !model.still { model.now = Date() }
        }
        .environment(\.locale, Lang.locale)
    }
}

struct SheetContent: View {
    let sheet: ActiveSheet
    var body: some View {
        switch sheet {
        case .settings: SettingsView()
        case .paywall: PaywallView()
        case .zukan: ZukanView()
        case .menus: MenusView()
        case .fridge: FridgeView()
        case .share(let id): ShareSheetView(id: id)
        }
    }
}

/// 見本の局（撮影・デモ・UI テスト）。山の順を決めてあるので、2 回捨てて 3 枚目で和了れる
enum Samples {
    static func k(_ id: String) -> Int { Kitchen.ingredients.first { $0.id == id }?.index ?? 0 }

    /// 自分の手：生姜焼き・親子丼・麻婆豆腐がそろい、トマト・キャベツ・ご飯・パン
    static let yourHand = ["pork", "ginger", "soy", "chicken", "egg", "onion", "mince", "tofu", "garlic", "tomato", "cabbage", "rice", "bread"]
    /// 相手の手（どの料理にもならない組み合わせ。自分の待ちにならない食材だけ）
    static let rivalPool = ["bread", "cucumber", "clam", "salmon", "mackerel", "spinach", "chive", "radish", "eggplant", "pepper", "potato", "beef", "shrimp", "leek"]

    static func round(pro: Bool = false) -> Round {
        let pool = rivalPool.map(k)
        let rivals = (0..<3).map { r in (0..<13).map { pool[($0 + r * 3) % pool.count] } }
        // 引く順：自分 なす → 相手 3 人 → 自分 玉ねぎ → 相手 3 人 → 自分 ご飯（ツモ）
        let draws = ["eggplant", "cucumber", "clam", "salmon", "onion", "spinach", "chive", "radish", "rice", "pepper", "potato", "beef", "shrimp", "leek", "bread", "cucumber"].map(k)
        return Round(yourHand: yourHand.map(k), draws: draws, rivalHands: rivals, recipes: Kitchen.recipeIndices(pro: pro))
    }
}

/// 起動の仕方：ふつう・撮影（-screenshotScene <名前>）・デモ（-demo）・UI テスト（-uiTestFresh）。
/// 撮影とデモは見本のデータで動かし、保存されたデータを書き換えない
@MainActor
enum Launch {
    /// 撮る画面の名前。後ろに _ja を付けると日本語で撮る（CI のシミュレータは英語のため）
    static var scene: String? {
        var value = UserDefaults.standard.string(forKey: "screenshotScene") ?? ""
        if value.hasSuffix("_ja") { value = String(value.dropLast(3)) }
        return value.isEmpty || value == "launch" ? nil : value
    }

    static var forcesJapanese: Bool {
        UserDefaults.standard.string(forKey: "screenshotScene")?.hasSuffix("_ja") ?? false
    }

    static var isDemo: Bool { ProcessInfo.processInfo.arguments.contains("-demo") }
    static var isFreshUITest: Bool { ProcessInfo.processInfo.arguments.contains("-uiTestFresh") }

    /// 撮影の時刻：今日の夕方 18:30（献立を決める時間）
    static func stageDate() -> Date {
        Calendar.current.date(bySettingHour: 18, minute: 30, second: 0, of: Date()) ?? Date()
    }

    /// アプリでただ 1 つのモデル（最初に読まれたときに 1 回だけ作る）
    static let shared: AppModel = makeModel()

    static func makeModel() -> AppModel {
        print("[MM] makeModel")
        Lang.forcedJapanese = forcesJapanese
        if isFreshUITest {
            for key in ["progress", "onboarded", "sound", "haptics", "strong", "paywallOffered"] {
                UserDefaults.standard.removeObject(forKey: key)
            }
            let model = AppModel()
            model.useSample = true
            model.soundOn = false
            return model
        }
        guard isDemo || scene != nil else { return AppModel() }
        let now = stageDate()
        let model = AppModel(persists: false, now: now)
        model.still = scene != nil
        model.useSample = true
        model.onboarded = scene != "onboarding"
        if scene != "fresh" && scene != "onboarding" {
            model.progress = samples(now: now, calendar: model.calendar)
        }
        if scene == "fridge" || scene == "paywall" { model.progress.fridge = ["onion", "egg", "cabbage", "tomato", "rice", "soy"] }
        return model
    }

    /// 見本の記録：きのうまでの 4 日の献立と、図鑑の 14 品
    static func samples(now: Date, calendar: Calendar) -> Progress {
        var p = Progress()
        let menus: [(Int, [Int], String, Int)] = [
            (-1, [0, 10, 33, 57], "rice", 3900),
            (-2, [29, 37, 41, 45], "noodle", 7700),
            (-3, [50, 52, 63, 64], "bread", 8000),
            (-4, [2, 5, 15, 18], "rice", 12000),
        ]
        for (day, dishes, pair, points) in menus {
            let date = calendar.date(byAdding: .day, value: day, to: now) ?? now
            let melds = dishes.map { Meld(kind: .recipe($0)) }
            let d = Decomposition(pair: Samples.k(pair), melds: melds)
            let score = Scorer.score(d, selfDrawn: day % 2 == 0)
            var record = MenuRecord(date: date, score: score, daily: true)
            record.points = points
            p.menus.append(record)
            for m in dishes { p.collected.insert(Kitchen.recipes[m].id) }
            p.dailyDays.insert(Progress.dayKey(date, calendar: calendar))
            p.dailyPoints[Progress.dayKey(date, calendar: calendar)] = points
        }
        p.wins = 4
        p.games = 7
        return p
    }

    static func run(_ model: AppModel) async {
        if isDemo {
            await Demo.play(model)
            return
        }
        guard let scene else { return }
        try? await Task.sleep(for: .milliseconds(300))
        switch scene {
        case "table", "select", "ron", "result", "share":
            model.startSample(Samples.round())
            guard var r = model.round else { return }
            // なすを捨て、相手 3 人が打ったところ（玉ねぎを引いた）
            r.discard(Samples.k("eggplant"))
            while r.phase == .rivals { r.rivalStep() }
            model.round = r
            if scene == "select" { model.selected = Samples.k("bread") }
            if scene == "ron" {
                r.discard(Samples.k("bread"))
                r.rivalStep()
                // 撮影用：相手の捨て牌でそろう場面にする
                r.phase = .ronChance(from: 2, tile: Samples.k("rice"))
                r.rivers[2].append(Samples.k("rice"))
                model.round = r
            }
            if scene == "result" || scene == "share" {
                model.selected = Samples.k("bread")
                model.discardSelected()
                while model.round?.phase == .rivals { try? await Task.sleep(for: .milliseconds(50)) }
                model.tsumo()
                try? await Task.sleep(for: .milliseconds(200))
                model.showResult = true
                if scene == "share", let id = model.lastRecord?.id { model.activeSheet = .share(id) }
            }
        case "lose", "draw":
            // 決まった種で最後まで打ち、相手の和了り（lose）か流局（draw）になる局を探す
            for seed in UInt64(1)...200 {
                let r = playOut(seed: seed)
                let found: Bool
                switch r.phase {
                case .over(.rivalWin): found = scene == "lose"
                case .over(.exhausted): found = scene == "draw"
                default: found = false
                }
                if found {
                    model.mode = .free
                    model.round = r
                    model.showResult = true
                    break
                }
            }
        case "zukan": model.activeSheet = .zukan
        case "menus": model.activeSheet = .menus
        case "fridge": model.activeSheet = .fridge
        case "settings": model.activeSheet = .settings
        case "paywall": model.activeSheet = .paywall
        default: break
        }
    }
}

extension Launch {
    /// 自分はおすすめの牌を捨て続け、和了れても和了らずに最後まで打つ
    nonisolated static func playOut(seed: UInt64) -> Round {
        var r = Round(seed: seed, recipes: Kitchen.recipeIndices(pro: false), careless: 0.5)
        var steps = 0
        while !r.isOver && steps < 400 {
            steps += 1
            switch r.phase {
            case .yourTurn:
                if let d = Solver.suggestedDiscard(r.yourHand, recipes: r.recipes) { r.discard(d) }
            case .rivals: r.rivalStep()
            case .ronChance: r.passRon()
            case .over: break
            }
        }
        return r
    }
}

/// デモの再生（YouTube の録画用。人の操作なしで約 18 秒）
/// ホーム → 今日の一局 → ヒントで捨てる → 相手の番 → 品がそろう → ツモ → 円卓に献立 → 共有
@MainActor
enum Demo {
    static func play(_ model: AppModel) async {
        func wait(_ seconds: Double) async { try? await Task.sleep(for: .milliseconds(Int(seconds * 1000))) }
        await wait(2.0)
        model.start(.daily)
        await wait(2.2)
        model.tap(Samples.k("eggplant"))
        await wait(1.0)
        model.discardSelected()
        await wait(2.6)
        model.tap(Samples.k("bread"))
        await wait(1.0)
        model.discardSelected()
        await wait(2.6)
        model.tsumo()
        await wait(5.5)
        if let id = model.lastRecord?.id { model.activeSheet = .share(id) }
    }
}
