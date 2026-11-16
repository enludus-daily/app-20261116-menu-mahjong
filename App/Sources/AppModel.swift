import AudioToolbox
import Foundation
import Observation
import SwiftUI

/// どの一局か
enum GameMode: String, Equatable, Sendable {
    /// 今日の一局（日付の種。1 日 1 回、連続日数に数える）
    case daily
    /// 自由に一局
    case free
    /// 冷蔵庫モード（Pro。冷蔵庫にある食材が多く出る）
    case fridge
}

enum ActiveSheet: Identifiable, Equatable {
    case settings
    case paywall
    case zukan
    case menus
    case fridge
    case share(UUID)
    var id: String {
        switch self {
        case .settings: "settings"
        case .paywall: "paywall"
        case .zukan: "zukan"
        case .menus: "menus"
        case .fridge: "fridge"
        case .share(let id): "share-" + id.uuidString
        }
    }
}

@MainActor
@Observable
final class AppModel {
    // 保存する値
    var progress: Progress { didSet { save() } }
    var onboarded: Bool { didSet { store(onboarded, "onboarded") } }
    var soundOn: Bool { didSet { store(soundOn, "sound") } }
    var hapticsOn: Bool { didSet { store(hapticsOn, "haptics") } }
    /// 相手の強さ（false：やさしい、true：ふつう）
    var strongRivals: Bool { didSet { store(strongRivals, "strong") } }
    /// 最初の和了りのあとの Pro の案内は 1 回だけ
    var paywallOffered: Bool { didSet { store(paywallOffered, "paywallOffered") } }

    // 画面の状態
    var round: Round?
    var mode: GameMode = .free
    var selected: Int?
    var showResult = false
    var activeSheet: ActiveSheet?
    var lastRecord: MenuRecord?
    var now: Date
    /// 撮影・デモのときは時間を止め、相手の番を待たない
    var still = false
    /// 今日の一局を見本の局で始める（撮影・デモ・UI テスト）
    var useSample = false

    // 手応え（値が変わると振動・音）
    var pressTick = 0
    var discardTick = 0
    var meldTick = 0
    var ronTick = 0
    var winTick = 0
    var loseTick = 0

    let purchases: PurchaseStore
    var proOverride = false
    var isPro: Bool { proOverride || purchases.entitlements.isPro }

    private let persists: Bool
    @ObservationIgnored private var rivalTask: Task<Void, Never>?
    let calendar = Calendar.current

    static let bundleID = Bundle.main.bundleIdentifier ?? "com.enludus.daily.011"
    static var proID: String { ProductID.pro(bundleID: bundleID) }

    init(persists: Bool = true, now: Date = Date()) {
        self.persists = persists
        self.now = now
        let d = UserDefaults.standard
        if persists, let data = d.data(forKey: "progress"), let p = try? JSONDecoder().decode(Progress.self, from: data) {
            progress = p
        } else {
            progress = Progress()
        }
        onboarded = persists ? d.bool(forKey: "onboarded") : true
        soundOn = persists ? (d.object(forKey: "sound") as? Bool ?? true) : true
        hapticsOn = persists ? (d.object(forKey: "haptics") as? Bool ?? true) : true
        strongRivals = persists ? d.bool(forKey: "strong") : false
        paywallOffered = persists ? d.bool(forKey: "paywallOffered") : true
        purchases = PurchaseStore(productIDs: [Self.proID], proProductIDs: [Self.proID])
    }

    private func save() {
        guard persists, let data = try? JSONEncoder().encode(progress) else { return }
        UserDefaults.standard.set(data, forKey: "progress")
    }

    private func store(_ value: Bool, _ key: String) {
        guard persists else { return }
        UserDefaults.standard.set(value, forKey: key)
    }

    // MARK: - 遊べる役・冷蔵庫

    var recipes: [Int] { Kitchen.recipeIndices(pro: isPro) }
    var fridgeKinds: Set<Int> {
        Set(Kitchen.ingredients.filter { progress.fridge.contains($0.id) }.map(\.index))
    }
    /// 冷蔵庫モードを始められるか（Pro か、お試しが残っている）
    var canPlayFridge: Bool { isPro || !progress.fridgeTrialUsed }
    var playedToday: Bool { progress.playedDaily(on: now, calendar: calendar) }
    var streak: Int { progress.streak(today: now, calendar: calendar) }
    /// 献立帳に見せる数（Pro はすべて）
    var visibleMenus: [MenuRecord] { isPro ? progress.menus : Array(progress.menus.prefix(5)) }

    // MARK: - 一局

    func start(_ mode: GameMode) {
        press()
        if mode == .fridge && !canPlayFridge {
            activeSheet = .paywall
            return
        }
        if mode == .fridge && progress.fridge.isEmpty {
            activeSheet = .fridge
            return
        }
        if mode == .fridge && !isPro { progress.fridgeTrialUsed = true }
        self.mode = mode
        let seed: UInt64 = mode == .daily ? Progress.dailySeed(now, calendar: calendar) : UInt64.random(in: 1...UInt64.max)
        if useSample && mode == .daily {
            round = Samples.round(pro: isPro)
        } else {
            round = Round(seed: seed, recipes: recipes, careless: strongRivals ? 0.3 : 0.6, fridge: mode == .fridge ? fridgeKinds : [])
        }
        selected = nil
        showResult = false
        lastRecord = nil
    }

    /// 見本の局で始める（撮影・デモ・UI テスト）
    func startSample(_ sample: Round, mode: GameMode = .daily) {
        self.mode = mode
        round = sample
        selected = nil
        showResult = false
    }

    /// 牌を押す：1 回目で選び、選んだ牌をもう一度押すと捨てる
    func tap(_ kind: Int) {
        guard round?.phase == .yourTurn else { return }
        if selected == kind {
            discardSelected()
        } else {
            selected = kind
            press()
        }
    }

    func discardSelected() {
        guard let kind = selected, var r = round, r.phase == .yourTurn else { return }
        r.discard(kind)
        round = r
        selected = nil
        discardTick += 1
        play(1104)
        runRivals()
    }

    /// おすすめの捨て牌を選ぶ（ヒント）
    func hint() {
        guard let r = round, r.phase == .yourTurn else { return }
        selected = Solver.suggestedDiscard(r.yourHand, recipes: r.recipes)
        press()
    }

    func tsumo() {
        guard var r = round, r.canTsumo else { return }
        r.tsumo()
        round = r
        finish()
    }

    func ron() {
        guard var r = round else { return }
        r.ron()
        round = r
        ronTick += 1
        finish()
    }

    func passRon() {
        guard var r = round else { return }
        r.passRon()
        round = r
        press()
        runRivals()
    }

    /// 相手の番を、間をあけて 1 人ずつ進める
    func runRivals() {
        rivalTask?.cancel()
        rivalTask = Task { [weak self] in
            guard let self else { return }
            while let r = self.round, r.phase == .rivals {
                if !self.still { try? await Task.sleep(for: .milliseconds(420)) }
                if Task.isCancelled { return }
                guard var next = self.round else { return }
                next.rivalStep()
                self.round = next
                if case .ronChance = next.phase {
                    self.ronTick += 1
                    self.play(1057)
                }
            }
            guard let r = self.round else { return }
            if r.isOver {
                self.finish()
            } else if r.phase == .yourTurn {
                // 引いた牌で、そろった品が増えたら知らせる
                let now = Solver.partial(r.yourHand, recipes: r.recipes).melds.count
                let before = Solver.partial(Array(r.yourHand.dropLast()), recipes: r.recipes).melds.count
                if now > before { self.meldTick += 1 }
            }
        }
    }

    /// 局が終わった：記録して結果へ
    private func finish() {
        guard let r = round, case .over(let outcome) = r.phase else { return }
        progress.games += 1
        var points = 0
        if case .youWin = outcome, let score = r.yourScore {
            let record = MenuRecord(date: now, score: score, daily: mode == .daily)
            progress.recordWin(record)
            lastRecord = record
            points = score.points
            winTick += 1
            play(1025)
        } else {
            loseTick += 1
            play(1053)
        }
        if mode == .daily { progress.recordDaily(now, points: points, calendar: calendar) }
        Task { [weak self] in
            if !(self?.still ?? true) { try? await Task.sleep(for: .milliseconds(650)) }
            self?.showResult = true
        }
    }

    /// 結果を閉じてホームへ。最初の和了りのあとだけ Pro の案内を出す
    func closeRound() {
        press()
        let won = lastRecord != nil
        showResult = false
        round = nil
        selected = nil
        if won && !paywallOffered && !isPro {
            paywallOffered = true
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(800))
                self?.activeSheet = .paywall
            }
        }
    }

    func again() {
        let m = mode == .daily ? GameMode.free : mode
        showResult = false
        start(m == .fridge && !canPlayFridge ? .free : m)
    }

    func toggleFridge(_ kind: Int) {
        let id = Kitchen.ingredients[kind].id
        if progress.fridge.contains(id) { progress.fridge.remove(id) } else if progress.fridge.count < 10 { progress.fridge.insert(id) }
        press()
    }

    // MARK: - 手応え

    func press() {
        pressTick += 1
    }

    func play(_ id: SystemSoundID) {
        guard soundOn, !still else { return }
        AudioServicesPlaySystemSound(id)
    }
}
