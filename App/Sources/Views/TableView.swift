import SwiftUI

/// 雀卓：上に相手 3 人と捨て牌、まん中に山の残りと最後の捨て牌、下に作りかけの献立と自分の手。
/// iPhone Duo の内側など横に広い画面（regular）では、右に献立と買い物メモを並べる。
struct TableView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var hSize

    var body: some View {
        if let round = model.round {
            Group {
                if hSize == .regular {
                    HStack(spacing: 0) {
                        table(round)
                        SidePanel(round: round)
                            .frame(width: 340)
                            .background(Theme.night)
                    }
                } else {
                    table(round)
                }
            }
            .background(NightBackground())
        }
    }

    private func table(_ round: Round) -> some View {
        VStack(spacing: 10) {
            TopBar(round: round)
            RivalsRow(round: round)
            CenterFelt(round: round)
            if hSize != .regular {
                Forming(round: round)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .safeAreaInset(edge: .bottom) {
            HandArea(round: round)
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
        }
    }
}

// MARK: - 上の帯

private struct TopBar: View {
    @Environment(AppModel.self) private var model
    let round: Round

    var body: some View {
        HStack {
            Button {
                model.closeRound()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
            }
            .buttonStyle(ChipButtonStyle())
            .accessibilityLabel(tr("やめてホームへ", "Leave the table"))
            .accessibilityIdentifier("table.close")
            Spacer()
            Signboard(compact: true) {
                Text(modeName)
                    .font(Theme.sign(14))
                    .kerning(1)
                    .foregroundStyle(Theme.goldSoft)
            }
            Spacer()
            VStack(spacing: 0) {
                Text(tr("山", "Wall"))
                    .font(Theme.label(.caption2, weight: .bold))
                    .foregroundStyle(Theme.creamSoft)
                Text("\(round.wallCount)")
                    .font(Theme.number(18))
                    .foregroundStyle(Theme.cream)
                    .contentTransition(.numericText())
            }
            .frame(minWidth: 44)
            .accessibilityElement(children: .combine)
        }
    }

    private var modeName: String {
        switch model.mode {
        case .daily: tr("今日の一局", "Today's Hand")
        case .free: tr("自由に一局", "Free play")
        case .fridge: tr("冷蔵庫の一局", "Fridge mode")
        }
    }
}

// MARK: - 相手

private struct RivalsRow: View {
    let round: Round

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(1..<4, id: \.self) { p in
                RivalSeat(round: round, seat: p)
            }
        }
    }
}

private struct RivalSeat: View {
    let round: Round
    let seat: Int

    private var rival: Rival { Rival.all[seat - 1] }
    private var active: Bool { round.phase == .rivals && round.turn == seat }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(rival.glyph)
                    .font(Theme.carved(15))
                    .foregroundStyle(Theme.goldSoft)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(active ? Theme.lacquer : Theme.wood))
                    .overlay(Circle().strokeBorder(Theme.gold.opacity(active ? 1 : 0.4), lineWidth: 1.2))
                    .scaleEffect(active ? 1.12 : 1)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: active)
                Text(rival.name)
                    .font(Theme.label(.caption2, weight: .bold))
                    .foregroundStyle(Theme.cream)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
            // 捨て牌（最後の 6 枚）
            HStack(spacing: 2) {
                ForEach(Array(round.rivers[seat].suffix(6).enumerated()), id: \.offset) { _, k in
                    TileView(kind: k, width: 15)
                }
            }
            .frame(height: 24, alignment: .leading)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.nightRaised.opacity(0.9)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(active ? Theme.gold : Theme.gold.opacity(0.15), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(trf("%@ 捨て牌 %d 枚", "%@, %d discards", rival.name, round.rivers[seat].count))
    }
}

// MARK: - まん中の卓

private struct CenterFelt: View {
    @Environment(AppModel.self) private var model
    let round: Round

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.rPanel, style: .continuous)
                .fill(Theme.wood)
            FeltBackground()
                .clipShape(RoundedRectangle(cornerRadius: Theme.rPanel - 5, style: .continuous))
                .padding(6)
            content
                .padding(14)
        }
        .frame(height: 150)
    }

    @ViewBuilder private var content: some View {
        switch round.phase {
        case .ronChance(let from, let tile):
            VStack(spacing: 8) {
                Text(trf("%@ の捨て牌で、献立がそろう！", "%@'s discard completes your menu!", Rival.all[from - 1].name))
                    .font(Theme.label(.footnote, weight: .bold))
                    .foregroundStyle(Theme.cream)
                    .multilineTextAlignment(.center)
                HStack(spacing: 14) {
                    TileView(kind: tile, width: 40, glow: true)
                    VStack(spacing: 8) {
                        Button(tr("ロン！", "Ron!")) { model.ron() }
                            .buttonStyle(LacquerButtonStyle(height: 44))
                            .accessibilityIdentifier("main.ron")
                        Button(tr("見送る", "Pass")) { model.passRon() }
                            .buttonStyle(LacquerButtonStyle(fill: Theme.nightRaised, text: Theme.cream, height: 36))
                            .accessibilityIdentifier("main.pass")
                    }
                    .frame(width: 150)
                }
            }
        case .over(let outcome):
            Text(overText(outcome))
                .font(Theme.sign(26))
                .foregroundStyle(Theme.goldSoft)
                .shadow(color: .black.opacity(0.5), radius: 0, y: 2)
                .transition(.scale(scale: 0.6).combined(with: .opacity))
        default:
            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text(tr("最後の捨て牌", "Last discard"))
                        .font(Theme.label(.caption2, weight: .bold))
                        .foregroundStyle(Theme.cream.opacity(0.75))
                    if let last = lastDiscard {
                        TileView(kind: last, width: 40, showName: true)
                            .id(round.rivers.map(\.count).reduce(0, +))
                            .transition(.asymmetric(insertion: .scale(scale: 1.4).combined(with: .opacity), removal: .opacity))
                    } else {
                        RoundedRectangle(cornerRadius: 6).strokeBorder(.white.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4]))
                            .frame(width: 40, height: 58)
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(turnText)
                        .font(Theme.label(.subheadline, weight: .heavy))
                        .foregroundStyle(Theme.goldSoft)
                    Text(waitText)
                        .font(Theme.label(.caption, weight: .semibold))
                        .foregroundStyle(Theme.cream.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.7), value: round.rivers.map(\.count).reduce(0, +))
        }
    }

    private var lastDiscard: Int? {
        let p = (round.turn + 3) % 4
        return round.rivers[p].last ?? round.rivers.compactMap(\.last).last
    }

    private var turnText: String {
        if round.phase == .yourTurn {
            return round.canTsumo ? tr("そろった！ ツモで和了る", "Complete! Call Tsumo") : tr("あなたの番：1 枚捨てる", "Your turn: discard one")
        }
        return trf("%@ の番", "%@ is playing", Rival.all[max(0, round.turn - 1)].name)
    }

    private var waitText: String {
        let hand = round.yourHand
        guard hand.count == 13 else {
            return tr("3 枚で 1 品、同じ 2 枚で主食。4 品そろえて和了り。", "3 tiles make a dish, a pair makes the staple. 4 dishes + 1 pair wins.")
        }
        let waits = Solver.waits(hand, recipes: round.recipes)
        if waits.isEmpty { return tr("まだテンパイではありません。料理になりそうな牌を残そう。", "Not ready yet. Keep tiles that cook together.") }
        let names = waits.prefix(4).map { Kitchen.ingredients[$0].name }.joined(separator: Lang.isJapanese ? "・" : ", ")
        return trf("テンパイ！ 待ち：%@", "Ready! Waiting on: %@", names)
    }

    private func overText(_ outcome: Outcome) -> String {
        switch outcome {
        case .youWin(let selfDrawn, _): selfDrawn ? tr("ツモ！", "Tsumo!") : tr("ロン！", "Ron!")
        case .rivalWin: tr("和了られた…", "Beaten to it…")
        case .exhausted: tr("流局", "Draw")
        }
    }
}

// MARK: - 作りかけの献立

struct Forming: View {
    @Environment(AppModel.self) private var model
    let round: Round
    var vertical = false

    var body: some View {
        let partial = Solver.partial(round.yourHand, recipes: round.recipes)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(tr("作りかけの献立", "Menu in progress"))
                    .font(Theme.label(.caption, weight: .heavy))
                    .foregroundStyle(Theme.goldSoft)
                Spacer()
                Text(trf("%d / 4 品", "%d / 4 dishes", partial.melds.count))
                    .font(Theme.number(13))
                    .foregroundStyle(Theme.cream)
                    .contentTransition(.numericText())
            }
            let chips = Group {
                ForEach(Array(partial.melds.enumerated()), id: \.offset) { _, m in
                    DishChip(name: m.name, cuisine: m.cuisine, done: true, missing: nil)
                }
                if let p = partial.pair {
                    DishChip(name: Kitchen.pairName(p), cuisine: nil, done: true, missing: nil, staple: true)
                }
                ForEach(Array(partial.nearly.prefix(vertical ? 8 : 3).enumerated()), id: \.offset) { _, n in
                    DishChip(name: Kitchen.recipes[n.recipe].name, cuisine: Kitchen.recipes[n.recipe].cuisine, done: false, missing: n.missing)
                }
            }
            if vertical {
                VStack(alignment: .leading, spacing: 6) { chips }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) { chips }
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.nightRaised.opacity(0.85)))
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: partial.melds.count)
    }
}

struct DishChip: View {
    let name: String
    let cuisine: Cuisine?
    let done: Bool
    let missing: Int?
    var staple = false

    var body: some View {
        HStack(spacing: 5) {
            if staple {
                Text(verbatim: "飯").font(Theme.carved(11)).foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Theme.inkFor(.staple)))
            } else {
                CuisineMark(cuisine: cuisine, size: 18)
            }
            Text(name)
                .font(Theme.label(.caption, weight: .bold))
                .foregroundStyle(done ? Theme.ink : Theme.cream)
                .lineLimit(1)
            if let m = missing {
                Text(trf("あと %@", "needs %@", Kitchen.ingredients[m].glyph))
                    .font(Theme.label(.caption2, weight: .heavy))
                    .foregroundStyle(Theme.gold)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(done ? Theme.goldSoft : Color.clear)
        )
        .overlay(
            Capsule().strokeBorder(done ? Color.clear : Theme.gold.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: done ? [] : [3, 2]))
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - 自分の手

private struct HandArea: View {
    @Environment(AppModel.self) private var model
    let round: Round

    var body: some View {
        VStack(spacing: 8) {
            info
            GeometryReader { geo in
                let tiles = round.displayHand
                let gap: CGFloat = 2
                let extra: CGFloat = round.drawn != nil ? 8 : 0
                let w = min(44, (geo.size.width - gap * CGFloat(max(0, tiles.count - 1)) - extra) / CGFloat(max(tiles.count, 13)))
                HStack(alignment: .bottom, spacing: gap) {
                    ForEach(Array(tiles.enumerated()), id: \.offset) { i, k in
                        let isDrawn = round.drawn != nil && i == tiles.count - 1
                        Button {
                            model.tap(k)
                        } label: {
                            TileView(kind: k, width: w, selected: model.selected == k, glow: isDrawn)
                                .offset(y: model.selected == k ? -12 : 0)
                                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: model.selected)
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, isDrawn ? extra : 0)
                        .accessibilityIdentifier("main.tile." + Kitchen.ingredients[k].id)
                        .accessibilityLabel(Kitchen.ingredients[k].name)
                        .accessibilityAddTraits(model.selected == k ? .isSelected : [])
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .frame(height: 74)
            actions
        }
        .padding(.top, 10)
        .padding(.bottom, 6)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: Theme.rPanel, style: .continuous)
                .fill(LinearGradient(colors: [Theme.woodLight, Theme.wood], startPoint: .top, endPoint: .bottom))
        )
        .overlay(RoundedRectangle(cornerRadius: Theme.rPanel, style: .continuous).strokeBorder(Theme.gold.opacity(0.35), lineWidth: 1))
    }

    /// 選んだ牌の名前と、その牌で作れる料理
    @ViewBuilder private var info: some View {
        if let k = model.selected {
            let names = round.recipes.filter { Kitchen.recipes[$0].parts.contains(k) }
                .sorted { usefulness($0) > usefulness($1) }
                .prefix(3).map { Kitchen.recipes[$0].name }
            HStack(spacing: 6) {
                Text(Kitchen.ingredients[k].name)
                    .font(Theme.label(.footnote, weight: .heavy))
                    .foregroundStyle(Theme.goldSoft)
                Text(names.isEmpty ? tr("づくし・主食に", "Good for pairs") : names.joined(separator: Lang.isJapanese ? "・" : ", "))
                    .font(Theme.label(.caption2, weight: .semibold))
                    .foregroundStyle(Theme.cream.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
            }
            .frame(height: 18)
        } else {
            Text(round.phase == .yourTurn ? tr("牌を押して選び、もう一度押すと捨てます", "Tap a tile to pick it, tap again to discard") : tr("相手の番です", "Rivals are playing"))
                .font(Theme.label(.caption2, weight: .semibold))
                .foregroundStyle(Theme.cream.opacity(0.75))
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 18)
        }
    }

    private func usefulness(_ recipe: Int) -> Int {
        Kitchen.recipes[recipe].parts.filter { round.yourHand.contains($0) }.count
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Button {
                model.hint()
            } label: {
                Label(tr("ヒント", "Hint"), systemImage: "lightbulb")
            }
            .buttonStyle(LacquerButtonStyle(fill: Theme.nightRaised, text: Theme.cream, height: 44))
            .disabled(round.phase != .yourTurn)
            .accessibilityIdentifier("main.hint")
            if round.canTsumo {
                Button(tr("ツモ！ 和了る", "Tsumo! Win")) { model.tsumo() }
                    .buttonStyle(LacquerButtonStyle(fill: Theme.goldDeep, text: .white, height: 44))
                    .accessibilityIdentifier("main.tsumo")
            }
            Button(tr("捨てる", "Discard")) { model.discardSelected() }
                .buttonStyle(LacquerButtonStyle(height: 44))
                .disabled(model.selected == nil || round.phase != .yourTurn)
                .opacity(model.selected == nil ? 0.55 : 1)
                .accessibilityIdentifier("main.discard")
        }
    }
}

// MARK: - 右の献立（広い画面）

private struct SidePanel: View {
    let round: Round

    var body: some View {
        let partial = Solver.partial(round.yourHand, recipes: round.recipes)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Forming(round: round, vertical: true)
                OrderSlip(title: tr("御献立（仮）", "Tonight's menu (draft)")) {
                    VStack(alignment: .leading, spacing: 9) {
                        if partial.melds.isEmpty {
                            Text(tr("そろった品がここに並びます。", "Completed dishes appear here."))
                                .font(Theme.label(.footnote))
                                .foregroundStyle(Theme.inkSoft)
                        }
                        ForEach(Array(partial.melds.enumerated()), id: \.offset) { _, m in
                            HStack(spacing: 6) {
                                CuisineMark(cuisine: m.cuisine, size: 18)
                                Text(m.name).font(Theme.label(.subheadline, weight: .bold)).foregroundStyle(Theme.ink)
                            }
                        }
                        let items = Shopping.list(melds: partial.melds, pair: partial.pair)
                        if !partial.melds.isEmpty {
                            Text(tr("買い物メモ", "Shopping list"))
                                .font(Theme.label(.caption, weight: .heavy))
                                .foregroundStyle(Theme.lacquer)
                                .padding(.top, 4)
                            Text(items.map { Kitchen.ingredients[$0.kind].name }.joined(separator: Lang.isJapanese ? "・" : ", "))
                                .font(Theme.label(.footnote))
                                .foregroundStyle(Theme.ink)
                        }
                    }
                }
            }
            .padding(16)
        }
    }
}
