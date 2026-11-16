import SwiftUI

/// ホーム：看板・今日の一局・自由に一局・冷蔵庫の一局・今夜の献立・図鑑と献立帳
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var hSize

    var body: some View {
        VStack(spacing: 14) {
            header
            if hSize == .regular {
                HStack(alignment: .top, spacing: 16) {
                    VStack(spacing: 14) { dailyCard; modeButtons }
                    tonight
                }
            } else {
                dailyCard
                modeButtons
                tonight
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .frame(maxWidth: 860)
        .frame(maxWidth: .infinity)
        .safeAreaInset(edge: .bottom) { bottomBar }
        .background(NightBackground())
    }

    // MARK: 看板

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Signboard {
                VStack(spacing: 2) {
                    SignText(text: tr("献立マージャン", "Menu Mahjong"), size: 28)
                    Text(tr("そろえた役が、今夜の献立になる", "Your winning hand is tonight's dinner"))
                        .font(Theme.label(.caption2, weight: .bold))
                        .foregroundStyle(Theme.goldSoft.opacity(0.9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
            }
            VStack(spacing: 2) {
                Lantern(count: model.streak)
                Text(tr("連続", "streak"))
                    .font(Theme.label(.caption2, weight: .bold))
                    .foregroundStyle(Theme.creamSoft)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(trf("今日の一局 %d 日連続", "Daily streak: %d days", model.streak))
        }
    }

    // MARK: 今日の一局

    private var dailyCard: some View {
        let played = model.playedToday
        let key = Progress.dayKey(model.now, calendar: model.calendar)
        let points = model.progress.dailyPoints[key] ?? 0
        let peek = Round(seed: Progress.dailySeed(model.now, calendar: model.calendar), recipes: Kitchen.recipeIndices(pro: false)).displayHand
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(tr("今日の一局", "Today's Hand"))
                    .font(Theme.sign(20))
                    .foregroundStyle(Theme.goldSoft)
                Spacer()
                Text(model.now.formatted(.dateTime.month().day().weekday(.abbreviated).locale(Lang.locale)))
                    .font(Theme.label(.caption, weight: .bold))
                    .foregroundStyle(Theme.cream.opacity(0.85))
            }
            Text(tr("だれが打っても同じ配牌。1 日 1 局で、連続日数がのびる。", "Same deal for everyone. One hand a day keeps your streak going."))
                .font(Theme.label(.caption))
                .foregroundStyle(Theme.cream.opacity(0.85))
            // 配牌の最初の 5 枚をのぞかせる（残りは伏せる）
            HStack(spacing: 3) {
                ForEach(Array(peek.prefix(5).enumerated()), id: \.offset) { _, k in
                    TileView(kind: k, width: 22)
                }
                ForEach(0..<6, id: \.self) { _ in TileBack(width: 22) }
                Spacer(minLength: 0)
            }
            Button {
                print("[MM] daily button action model=\(ObjectIdentifier(model).hashValue)")
                model.start(.daily)
            } label: {
                if played {
                    Text(points > 0 ? trf("今日は和了り %d 点。また明日", "Won %d pts today. See you tomorrow", points) : tr("今日は打ちました。また明日", "Played today. See you tomorrow"))
                } else {
                    Text(tr("今日の一局を打つ", "Play today's hand"))
                }
            }
            .buttonStyle(LacquerButtonStyle())
            .disabled(played)
            .accessibilityIdentifier("main.daily")
        }
        .padding(14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: Theme.rPanel, style: .continuous).fill(Theme.wood)
                FeltBackground().clipShape(RoundedRectangle(cornerRadius: Theme.rPanel - 5, style: .continuous)).padding(5)
            }
        )
    }

    // MARK: 自由に・冷蔵庫

    private var modeButtons: some View {
        HStack(spacing: 10) {
            Button {
                model.start(.free)
            } label: {
                VStack(spacing: 2) {
                    Text(tr("自由に一局", "Free play"))
                    Text(tr("何局でも", "Unlimited"))
                        .font(Theme.label(.caption2, weight: .semibold))
                        .opacity(0.8)
                }
            }
            .buttonStyle(LacquerButtonStyle(fill: Theme.feltLight, text: .white, height: 58))
            .accessibilityIdentifier("main.free")
            Button {
                model.start(.fridge)
            } label: {
                VStack(spacing: 2) {
                    HStack(spacing: 4) {
                        Text(tr("冷蔵庫の一局", "Fridge mode"))
                        if !model.isPro {
                            Text("PRO")
                                .font(.system(size: 9, weight: .black, design: .rounded))
                                .padding(.horizontal, 4).padding(.vertical, 1)
                                .background(Capsule().fill(Theme.gold))
                                .foregroundStyle(Theme.night)
                        }
                    }
                    Text(fridgeSub)
                        .font(Theme.label(.caption2, weight: .semibold))
                        .opacity(0.8)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .buttonStyle(LacquerButtonStyle(fill: Theme.goldDeep, text: .white, height: 58))
            .accessibilityIdentifier("main.fridge")
        }
    }

    private var fridgeSub: String {
        if !model.isPro && !model.progress.fridgeTrialUsed { return tr("1 回だけお試し", "One free try") }
        if model.progress.fridge.isEmpty { return tr("中身を選んで", "Pick what you have") }
        return trf("食材 %d 種", "%d ingredients", model.progress.fridge.count)
    }

    // MARK: 今夜の献立

    private var tonight: some View {
        OrderSlip(title: tr("今夜の御献立", "Tonight's Menu")) {
            if let record = model.progress.menus.first {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(record.melds.enumerated()), id: \.offset) { _, m in
                        HStack(spacing: 6) {
                            CuisineMark(cuisine: m.cuisine, size: 16)
                            Text(m.name).font(Theme.label(.footnote, weight: .bold)).foregroundStyle(Theme.ink).lineLimit(1)
                        }
                    }
                    HStack {
                        Text("+ " + Kitchen.pairName(record.pairKind)).font(Theme.label(.footnote, weight: .bold)).foregroundStyle(Theme.ink)
                        Spacer()
                        Text(trf("%d 点", "%d pts", record.points)).font(Theme.number(13)).foregroundStyle(Theme.lacquer)
                    }
                    Button {
                        model.press()
                        model.activeSheet = .fridge
                    } label: {
                        Text(tr("冷蔵庫の中身を選ぶ", "Set up your fridge"))
                            .font(Theme.label(.caption, weight: .bold))
                            .foregroundStyle(Theme.lacquer)
                            .frame(minHeight: 30)
                    }
                    .accessibilityIdentifier("home.fridgeEdit")
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text(tr("まだ献立はありません。", "No menu yet."))
                        .font(Theme.label(.footnote, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text(tr("今日の一局で和了ると、そろえた料理と買い物メモがここに残ります。", "Win today's hand and your dishes and shopping list land here."))
                        .font(Theme.label(.caption))
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: 下の帯

    private var bottomBar: some View {
        HStack(spacing: 8) {
            barButton(id: "main.zukan", glyph: "図", title: tr("図鑑", "Dishes"), sub: "\(model.progress.collected.count)/\(model.recipes.count)") {
                model.activeSheet = .zukan
            }
            barButton(id: "main.menus", glyph: "帳", title: tr("献立帳", "Menu Book"), sub: "\(model.progress.menus.count)") {
                model.activeSheet = .menus
            }
            barButton(id: "main.settings", glyph: "設", title: tr("設定", "Settings"), sub: model.isPro ? "PRO" : "") {
                model.activeSheet = .settings
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private func barButton(id: String, glyph: String, title: String, sub: String, action: @escaping () -> Void) -> some View {
        Button {
            model.press()
            action()
        } label: {
            HStack(spacing: 6) {
                Text(glyph)
                    .font(Theme.carved(17))
                    .foregroundStyle(Theme.lacquer)
                    .frame(width: 26, height: 32)
                    .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Theme.ivory))
                    .shadow(color: Theme.jadeDeep, radius: 0, y: 2.5)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).font(Theme.label(.footnote, weight: .heavy)).foregroundStyle(Theme.cream)
                        .lineLimit(1).minimumScaleFactor(0.65)
                    if !sub.isEmpty {
                        Text(sub).font(Theme.number(11)).foregroundStyle(Theme.gold)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.nightRaised))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.gold.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}
