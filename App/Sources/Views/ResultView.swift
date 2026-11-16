import SwiftUI

/// 局の終わり。和了ると、そろった料理が湯気とともに円卓に並び、今夜の献立と買い物メモが残る。
struct ResultView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var hSize

    var body: some View {
        if let round = model.round, case .over(let outcome) = round.phase {
            ScrollView {
                VStack(spacing: 18) {
                    header(outcome, round)
                    switch outcome {
                    case .youWin:
                        if let score = round.yourScore {
                            if hSize == .regular {
                                HStack(alignment: .top, spacing: 20) {
                                    VStack(spacing: 16) {
                                        Banquet(melds: score.decomposition.melds, pair: score.decomposition.pair, animated: !model.still)
                                        YakuList(score: score)
                                    }
                                    MenuSlip(melds: score.decomposition.melds, pair: score.decomposition.pair, fridge: model.mode == .fridge ? model.fridgeKinds : [])
                                }
                            } else {
                                Banquet(melds: score.decomposition.melds, pair: score.decomposition.pair, animated: !model.still)
                                YakuList(score: score)
                                MenuSlip(melds: score.decomposition.melds, pair: score.decomposition.pair, fridge: model.mode == .fridge ? model.fridgeKinds : [])
                            }
                        }
                    case .rivalWin(let p):
                        if let score = round.rivalScore {
                            Text(trf("%@ の献立", "%@'s menu", Rival.all[p - 1].name))
                                .font(Theme.label(.headline, weight: .heavy))
                                .foregroundStyle(Theme.cream)
                            Banquet(melds: score.decomposition.melds, pair: score.decomposition.pair, animated: !model.still, size: 260)
                        }
                        leftovers(round)
                    case .exhausted:
                        leftovers(round)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
                .frame(maxWidth: 820)
                .frame(maxWidth: .infinity)
            }
            .background(NightBackground())
            .safeAreaInset(edge: .bottom) { buttons(outcome) }
        }
    }

    private func header(_ outcome: Outcome, _ round: Round) -> some View {
        VStack(spacing: 8) {
            Signboard {
                SignText(text: title(outcome), size: 30)
            }
            if case .youWin = outcome, let score = round.yourScore {
                HStack(spacing: 8) {
                    if let rank = Scorer.rank(han: score.han, yakuman: score.isYakuman) {
                        Text(rank)
                            .font(Theme.sign(15))
                            .foregroundStyle(Theme.night)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(Theme.gold))
                    }
                    Text(trf("%d 点", "%d pts", score.points))
                        .font(Theme.number(30))
                        .kerning(-1)
                        .foregroundStyle(Theme.goldSoft)
                }
            } else {
                Text(outcome == .exhausted
                     ? tr("牌がなくなりました。手元の食材で作れる品はこちら。", "The wall ran out. Here's what your hand can still cook.")
                     : tr("今回は先を越されました。手元の食材で作れる品はこちら。", "Someone beat you to it. Here's what your hand can still cook."))
                    .font(Theme.label(.footnote))
                    .foregroundStyle(Theme.cream.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func title(_ outcome: Outcome) -> String {
        switch outcome {
        case .youWin(let selfDrawn, _): selfDrawn ? tr("ツモ・献立完成", "Tsumo — Dinner!") : tr("ロン・献立完成", "Ron — Dinner!")
        case .rivalWin: tr("和了られた", "Beaten")
        case .exhausted: tr("流局", "Draw")
        }
    }

    private func leftovers(_ round: Round) -> some View {
        let partial = Solver.partial(round.yourHand, recipes: round.recipes)
        return OrderSlip(title: tr("手元で作れる品", "What your hand can cook")) {
            VStack(alignment: .leading, spacing: 8) {
                if partial.melds.isEmpty {
                    Text(tr("そろった品はありませんでした。次は、料理になりそうな牌を残してみよう。", "No dishes this time. Next round, keep tiles that cook together."))
                        .font(Theme.label(.footnote))
                        .foregroundStyle(Theme.inkSoft)
                }
                ForEach(Array(partial.melds.enumerated()), id: \.offset) { _, m in
                    HStack {
                        CuisineMark(cuisine: m.cuisine, size: 18)
                        Text(m.name).font(Theme.label(.subheadline, weight: .bold)).foregroundStyle(Theme.ink)
                    }
                }
                ForEach(Array(partial.nearly.prefix(3).enumerated()), id: \.offset) { _, n in
                    Text(trf("あと %@ で「%@」", "One %@ away from %@", Kitchen.ingredients[n.missing].name, Kitchen.recipes[n.recipe].name))
                        .font(Theme.label(.footnote))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
        }
    }

    private func buttons(_ outcome: Outcome) -> some View {
        HStack(spacing: 10) {
            if case .youWin = outcome, let record = model.lastRecord {
                Button {
                    model.press()
                    model.activeSheet = .share(record.id)
                } label: {
                    Label(tr("共有", "Share"), systemImage: "square.and.arrow.up")
                }
                .buttonStyle(LacquerButtonStyle(fill: Theme.nightRaised, text: Theme.cream))
                .accessibilityIdentifier("main.share")
            }
            Button(tr("もう一局", "Play again")) { model.again() }
                .buttonStyle(LacquerButtonStyle(fill: Theme.feltLight, text: .white))
                .accessibilityIdentifier("main.again")
            Button(tr("ホームへ", "Home")) { model.closeRound() }
                .buttonStyle(LacquerButtonStyle())
                .accessibilityIdentifier("main.done")
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(Theme.night.opacity(0.96))
    }
}

/// 円卓：回転台の上に 4 品と、まん中に主食。皿は順に出て、湯気が立つ
struct Banquet: View {
    let melds: [Meld]
    let pair: Int
    var animated = true
    var size: CGFloat = 330
    @State private var shown = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let plate = size * 0.3
        ZStack {
            // 円卓（木）と回転台（ガラス）
            Circle().fill(RadialGradient(colors: [Theme.lacquer, Theme.lacquerDeep], center: .center, startRadius: 10, endRadius: size * 0.55))
                .overlay(Circle().strokeBorder(Theme.gold.opacity(0.6), lineWidth: 2))
            Circle().fill(.white.opacity(0.08))
                .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1))
                .padding(size * 0.2)
            ForEach(Array(melds.enumerated()), id: \.offset) { i, m in
                let angle = Angle.degrees(Double(i) * 90 - 45)
                dish(name: m.name, cuisine: m.cuisine, tiles: m.tiles, plate: plate, delay: Double(i) * 0.35)
                    .offset(x: CGFloat(cos(angle.radians)) * size * 0.31, y: CGFloat(sin(angle.radians)) * size * 0.31)
                    .opacity(i < visibleCount ? 1 : 0)
                    .scaleEffect(i < visibleCount ? 1 : 0.6)
            }
            // 主食
            VStack(spacing: 2) {
                ZStack {
                    Circle().fill(.white).frame(width: plate * 0.7, height: plate * 0.7)
                    Circle().strokeBorder(Theme.lacquer, lineWidth: 3).frame(width: plate * 0.7, height: plate * 0.7)
                    Text(Kitchen.ingredients[pair].glyph).font(Theme.carved(plate * 0.32)).foregroundStyle(Theme.inkFor(Kitchen.ingredients[pair].category))
                }
                Text(Kitchen.pairName(pair))
                    .font(Theme.label(.caption2, weight: .heavy))
                    .foregroundStyle(Theme.goldSoft)
            }
            .opacity(visibleCount >= melds.count ? 1 : 0)
        }
        .frame(width: size, height: size)
        .onAppear {
            guard animated && !reduceMotion else { shown = melds.count; return }
            for i in 0..<melds.count {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.62).delay(0.25 + Double(i) * 0.35)) { shown = i + 1 }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(melds.map(\.name).joined(separator: "、") + "、" + Kitchen.pairName(pair))
    }

    private var visibleCount: Int { animated && !reduceMotion ? shown : melds.count }

    private func dish(name: String, cuisine: Cuisine?, tiles: [Int], plate: CGFloat, delay: Double) -> some View {
        VStack(spacing: 3) {
            ZStack {
                Plate(size: plate)
                HStack(spacing: 1) {
                    ForEach(Array(Set(tiles)).sorted(), id: \.self) { k in
                        Text(Kitchen.ingredients[k].glyph)
                            .font(Theme.carved(plate * 0.2))
                            .foregroundStyle(Theme.inkFor(Kitchen.ingredients[k].category))
                    }
                }
                Steam(height: plate * 0.36, delay: 0.4 + delay, animated: animated)
                    .offset(y: -plate * 0.48)
            }
            HStack(spacing: 3) {
                CuisineMark(cuisine: cuisine, size: 14)
                Text(name)
                    .font(Theme.label(.caption2, weight: .heavy))
                    .foregroundStyle(Theme.cream)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: plate * 1.35)
        }
    }
}

/// 役の一覧
struct YakuList: View {
    let score: WinScore
    var body: some View {
        VStack(spacing: 6) {
            ForEach(score.yaku) { y in
                HStack {
                    Text(y.name)
                        .font(Theme.label(.subheadline, weight: .bold))
                        .foregroundStyle(Theme.cream)
                    Spacer()
                    Text(y.yakuman ? tr("役満", "Yakuman") : trf("%d 翻", "%d han", y.han))
                        .font(Theme.number(15))
                        .foregroundStyle(Theme.gold)
                }
                .padding(.vertical, 2)
                Rectangle().fill(Theme.gold.opacity(0.18)).frame(height: 0.7)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: Theme.rCard, style: .continuous).fill(Theme.nightRaised))
        .overlay(RoundedRectangle(cornerRadius: Theme.rCard, style: .continuous).strokeBorder(Theme.gold.opacity(0.3), lineWidth: 1))
    }
}

/// 今夜の献立（作り方）と買い物メモの伝票
struct MenuSlip: View {
    let melds: [Meld]
    let pair: Int
    var fridge: Set<Int> = []

    var body: some View {
        OrderSlip(title: tr("今夜の御献立", "Tonight's Menu")) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(melds.enumerated()), id: \.offset) { i, m in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("\(i + 1)").font(Theme.number(13)).foregroundStyle(Theme.lacquer)
                            CuisineMark(cuisine: m.cuisine, size: 16)
                            Text(m.name).font(Theme.label(.subheadline, weight: .heavy)).foregroundStyle(Theme.ink)
                        }
                        Text(m.recipe?.how ?? zukushiHow(m))
                            .font(Theme.label(.caption))
                            .foregroundStyle(Theme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                HStack(spacing: 6) {
                    Text("+").font(Theme.number(13)).foregroundStyle(Theme.lacquer)
                    Text(Kitchen.pairName(pair)).font(Theme.label(.subheadline, weight: .heavy)).foregroundStyle(Theme.ink)
                }
                Rectangle().fill(Theme.slipRule).frame(height: 1)
                Text(tr("買い物メモ", "Shopping list"))
                    .font(Theme.label(.caption, weight: .heavy))
                    .foregroundStyle(Theme.lacquer)
                let items = Shopping.list(melds: melds, pair: pair, fridge: fridge)
                LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 6) {
                    ForEach(items) { item in
                        HStack(spacing: 5) {
                            Image(systemName: item.inFridge ? "checkmark.square.fill" : "square")
                                .foregroundStyle(item.inFridge ? Theme.inkFor(.veg) : Theme.inkSoft)
                                .font(.system(size: 13))
                            Text(Kitchen.ingredients[item.kind].name)
                                .font(Theme.label(.footnote, weight: .semibold))
                                .foregroundStyle(item.inFridge ? Theme.inkSoft : Theme.ink)
                                .strikethrough(item.inFridge)
                            if item.uses > 1 {
                                Text("×\(item.uses)").font(Theme.number(11)).foregroundStyle(Theme.lacquer)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    private func zukushiHow(_ m: Meld) -> String {
        guard case .triplet(let k) = m.kind else { return "" }
        let n = Kitchen.ingredients[k].name
        return trf("%@ を、焼く・煮る・あえるの 3 通りで。", "%@ three ways: seared, simmered and dressed.", n)
    }
}
