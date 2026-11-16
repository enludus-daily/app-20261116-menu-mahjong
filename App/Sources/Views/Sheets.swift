import StoreKit
import SwiftUI

/// シートの共通の枠（夜の地・題字・閉じる）
struct SheetFrame<Content: View>: View {
    let title: String
    var closeID = "sheet.close"
    @ViewBuilder var content: Content
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                SignText(text: title, size: 22)
                Spacer()
                Button {
                    model.press()
                    model.activeSheet = nil
                } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .bold))
                }
                .buttonStyle(ChipButtonStyle())
                .accessibilityLabel(tr("閉じる", "Close"))
                .accessibilityIdentifier(closeID)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)
            content
        }
        .background(NightBackground())
    }
}

// MARK: - 図鑑

struct ZukanView: View {
    @Environment(AppModel.self) private var model
    @State private var filter: Cuisine? = nil

    var body: some View {
        SheetFrame(title: tr("料理の図鑑", "Dish Collection"), closeID: "main.closeZukan") {
            VStack(spacing: 10) {
                HStack {
                    Text(trf("集めた料理 %d / %d", "Collected %d / %d", model.progress.collected.count, Kitchen.recipes.count))
                        .font(Theme.label(.subheadline, weight: .heavy))
                        .foregroundStyle(Theme.cream)
                    Spacer()
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        filterChip(nil, tr("すべて", "All"))
                        ForEach(Cuisine.allCases, id: \.self) { c in filterChip(c, c.name) }
                    }
                }
            }
            .padding(.horizontal, 16)
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 10)], spacing: 12) {
                    ForEach(Kitchen.recipes.filter { filter == nil || $0.cuisine == filter }) { r in
                        cell(r)
                    }
                }
                .padding(16)
            }
        }
    }

    private func filterChip(_ c: Cuisine?, _ title: String) -> some View {
        Button {
            model.press()
            withAnimation(.easeOut(duration: 0.2)) { filter = c }
        } label: {
            Text(title)
                .font(Theme.label(.caption, weight: .bold))
                .foregroundStyle(filter == c ? Theme.night : Theme.cream)
                .padding(.horizontal, 12)
                .frame(minHeight: 34)
                .background(Capsule().fill(filter == c ? Theme.gold : Theme.nightRaised))
        }
        .buttonStyle(.plain)
    }

    private func cell(_ r: Recipe) -> some View {
        let got = model.progress.collected.contains(r.id)
        let locked = r.pro && !model.isPro
        return VStack(spacing: 6) {
            ZStack {
                Plate(size: 64)
                    .opacity(got ? 1 : 0.35)
                HStack(spacing: 0) {
                    ForEach(r.parts, id: \.self) { k in
                        Text(Kitchen.ingredients[k].glyph)
                            .font(Theme.carved(14))
                            .foregroundStyle(got ? Theme.inkFor(Kitchen.ingredients[k].category) : Theme.inkSoft)
                    }
                }
                if locked {
                    Image(systemName: "lock.fill").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.gold).offset(x: 24, y: -24)
                }
            }
            HStack(spacing: 3) {
                CuisineMark(cuisine: r.cuisine, size: 13)
                Text(got ? r.name : tr("？？？", "???"))
                    .font(Theme.label(.caption2, weight: .bold))
                    .foregroundStyle(got ? Theme.cream : Theme.creamSoft)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
            .frame(height: 30)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.nightRaised.opacity(got ? 1 : 0.5)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(got ? r.name : tr("まだ作っていない料理", "Not cooked yet"))
    }
}

// MARK: - 献立帳

struct MenusView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        SheetFrame(title: tr("献立帳", "Menu Book"), closeID: "main.closeMenus") {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    weekPlan
                    if model.progress.menus.isEmpty {
                        Text(tr("まだ献立はありません。和了ると、ここに今夜の献立が残ります。", "No menus yet. Each win saves tonight's menu here."))
                            .font(Theme.label(.footnote))
                            .foregroundStyle(Theme.cream.opacity(0.8))
                    }
                    ForEach(model.visibleMenus) { record in
                        MenuSlip(melds: record.melds, pair: record.pairKind)
                            .overlay(alignment: .topTrailing) {
                                Text(record.date.formatted(.dateTime.month().day().locale(Lang.locale)))
                                    .font(Theme.number(11))
                                    .foregroundStyle(Theme.slipRule)
                                    .padding(.top, 34).padding(.trailing, 14)
                            }
                    }
                    if !model.isPro && model.progress.menus.count > 5 {
                        proNote(trf("ほかに %d 件の献立があります。Pro ですべて見られます。", "%d older menus saved. Pro shows them all.", model.progress.menus.count - 5))
                    }
                }
                .padding(16)
            }
        }
    }

    /// 1 週間の献立表（Pro）
    private var weekPlan: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(tr("今週の献立表", "This week's plan"))
                    .font(Theme.label(.headline, weight: .heavy))
                    .foregroundStyle(Theme.goldSoft)
                if !model.isPro {
                    Text("PRO").font(.system(size: 9, weight: .black, design: .rounded))
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Capsule().fill(Theme.gold)).foregroundStyle(Theme.night)
                }
            }
            let week = model.progress.week(of: model.now, calendar: model.calendar)
            VStack(spacing: 0) {
                ForEach(Array(week.enumerated()), id: \.offset) { i, day in
                    HStack(alignment: .top, spacing: 10) {
                        Text(day.day.formatted(.dateTime.weekday(.abbreviated).locale(Lang.locale)))
                            .font(Theme.label(.caption, weight: .heavy))
                            .foregroundStyle(model.calendar.isDate(day.day, inSameDayAs: model.now) ? Theme.gold : Theme.cream)
                            .frame(width: 40, alignment: .leading)
                        if let menu = day.menu {
                            Text(menu.melds.map(\.name).joined(separator: Lang.isJapanese ? "・" : ", "))
                                .font(Theme.label(.caption))
                                .foregroundStyle(Theme.cream)
                                .lineLimit(2)
                                .blur(radius: model.isPro ? 0 : 3)
                        } else {
                            Text(tr("—", "—")).font(Theme.label(.caption)).foregroundStyle(Theme.creamSoft)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 7)
                    if i < 6 { Rectangle().fill(Theme.gold.opacity(0.15)).frame(height: 0.7) }
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: Theme.rCard, style: .continuous).fill(Theme.nightRaised))
            if !model.isPro {
                proNote(tr("Pro で、和了った献立が 1 週間の献立表になります。", "With Pro, your wins become a weekly dinner plan."))
            }
        }
    }

    private func proNote(_ text: String) -> some View {
        Button {
            model.press()
            model.activeSheet = .paywall
        } label: {
            HStack {
                Text(text).font(Theme.label(.caption, weight: .semibold)).multilineTextAlignment(.leading)
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
            }
            .foregroundStyle(Theme.gold)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.gold.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 冷蔵庫

struct FridgeView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        SheetFrame(title: tr("冷蔵庫の中身", "Your Fridge"), closeID: "main.closeFridge") {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(tr("いま家にある食材を 10 種まで選ぶと、冷蔵庫の一局ではその牌が多く出て、買い物メモから外れます。", "Pick up to 10 ingredients you have. In Fridge mode they show up more often and drop off your shopping list."))
                        .font(Theme.label(.footnote))
                        .foregroundStyle(Theme.cream.opacity(0.88))
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(FoodGroup.allCases, id: \.self) { cat in
                        let items = Kitchen.ingredients.filter { $0.category == cat }
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 8)], spacing: 10) {
                            ForEach(items) { i in
                                let on = model.progress.fridge.contains(i.id)
                                Button {
                                    model.toggleFridge(i.index)
                                } label: {
                                    TileView(kind: i.index, width: 52, selected: on, glow: on, showName: true)
                                        .opacity(on ? 1 : 0.6)
                                        .offset(y: on ? -4 : 0)
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(on ? .isSelected : [])
                            }
                        }
                    }
                }
                .padding(16)
            }
            .safeAreaInset(edge: .bottom) {
                Button(trf("この %d 種で一局", "Play with these %d", model.progress.fridge.count)) {
                    model.activeSheet = nil
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(400))
                        model.start(.fridge)
                    }
                }
                .buttonStyle(LacquerButtonStyle(fill: Theme.goldDeep, text: .white))
                .disabled(model.progress.fridge.isEmpty)
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
                .background(Theme.night.opacity(0.95))
            }
        }
    }
}

// MARK: - 設定

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        SheetFrame(title: tr("設定", "Settings"), closeID: "main.closeSettings") {
            ScrollView {
                VStack(spacing: 14) {
                    group(tr("卓", "Table")) {
                        Toggle(tr("相手を強くする", "Stronger rivals"), isOn: $model.strongRivals)
                        Toggle(tr("効果音", "Sound effects"), isOn: $model.soundOn)
                        Toggle(tr("振動", "Haptics"), isOn: $model.hapticsOn)
                    }
                    group(tr("冷蔵庫", "Fridge")) {
                        row(tr("冷蔵庫の中身を選ぶ", "Set up your fridge")) { model.activeSheet = .fridge }
                    }
                    group("Pro") {
                        if model.isPro {
                            Text(tr("Pro を使っています。ありがとうございます！", "You have Pro. Thank you!"))
                                .font(Theme.label(.footnote, weight: .bold))
                                .foregroundStyle(Theme.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            row(tr("Pro でできること", "What Pro adds")) { model.activeSheet = .paywall }
                        }
                        row(tr("購入を復元", "Restore purchases")) {
                            Task { await model.purchases.restore() }
                        }
                    }
                    group(tr("使い方", "Help")) {
                        row(tr("使い方をもう一度見る", "Show the intro again")) {
                            model.activeSheet = nil
                            model.onboarded = false
                        }
                        Text(tr("記録（献立・図鑑・連続日数）はこの端末の中だけに保存します。通信・ログイン・広告・解析はありません。", "Your menus, collection and streak stay on this device. No network, login, ads or analytics."))
                            .font(Theme.label(.caption))
                            .foregroundStyle(Theme.inkSoft)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Text(trf("和了り %d 回 / %d 局", "%d wins / %d hands", model.progress.wins, model.progress.games))
                        .font(Theme.number(13))
                        .foregroundStyle(Theme.creamSoft)
                }
                .padding(16)
            }
        }
    }

    private func group<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(Theme.label(.caption, weight: .heavy)).foregroundStyle(Theme.lacquer)
            content()
                .font(Theme.label(.subheadline, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .tint(Theme.lacquer)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: Theme.rCard, style: .continuous).fill(Theme.slip))
    }

    private func row(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            model.press()
            action()
        } label: {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.inkSoft)
            }
            .frame(minHeight: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pro

struct PaywallView: View {
    @Environment(AppModel.self) private var model
    @State private var busy = false
    @State private var message: String?

    var body: some View {
        SheetFrame(title: tr("献立マージャン Pro", "Menu Mahjong Pro"), closeID: "main.closePaywall") {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(tr("一度買えば、ずっと使えます（買い切り・家族共有）", "Pay once, keep it forever (one-time, Family Sharing)"))
                        .font(Theme.label(.footnote, weight: .bold))
                        .foregroundStyle(Theme.goldSoft)
                    feature("弁", tr("追加の役 32 品", "32 more dishes"),
                            tr("お弁当（から揚げ・肉巻きおにぎり…）と世界の料理（パエリア・ビビンバ・トムヤムクン…）が役に加わる。和了りやすく、献立の幅も広がる。", "Bento (karaage, pork-wrapped onigiri…) and world dishes (paella, bibimbap, tom yum…) join the rules. Easier wins, wider menus."))
                    feature("冷", tr("冷蔵庫の一局", "Fridge mode"),
                            tr("家にある食材を選ぶと、その牌が多く出る。和了った献立は「買うもの」だけが買い物メモに残る。", "Pick what you have; those tiles show up more. Your shopping list only shows what you need to buy."))
                    feature("帳", tr("献立帳をすべて・1 週間の献立表", "Full menu book + weekly plan"),
                            tr("無料では最新 5 件。Pro では全部の献立と、月〜日の献立表が見られる。", "Free keeps the latest 5. Pro keeps every menu and lays out your week, Mon–Sun."))
                    priceBox
                }
                .padding(16)
            }
        }
    }

    private func feature(_ glyph: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(glyph)
                .font(Theme.carved(22))
                .foregroundStyle(Theme.lacquer)
                .frame(width: 40, height: 54)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Theme.ivory))
                .shadow(color: Theme.jadeDeep, radius: 0, y: 4)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(Theme.label(.headline, weight: .heavy)).foregroundStyle(Theme.cream)
                Text(body).font(Theme.label(.footnote)).foregroundStyle(Theme.cream.opacity(0.85)).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: Theme.rCard, style: .continuous).fill(Theme.nightRaised))
    }

    @ViewBuilder private var priceBox: some View {
        VStack(spacing: 10) {
            if model.isPro {
                Text(tr("Pro を使っています", "Pro is active")).font(Theme.label(.headline, weight: .heavy)).foregroundStyle(Theme.gold)
            } else if let product = model.purchases.products.first {
                Button {
                    busy = true
                    Task {
                        let outcome = await model.purchases.purchase(product)
                        busy = false
                        switch outcome {
                        case .purchased: message = tr("ありがとうございます！ Pro が使えます。", "Thank you! Pro is unlocked.")
                        case .pending: message = tr("承認を待っています。", "Waiting for approval.")
                        case .failed: message = tr("購入できませんでした。時間をおいて試してください。", "Purchase failed. Please try again later.")
                        case .cancelled: break
                        }
                    }
                } label: {
                    Text(trf("Pro にする（%@・買い切り）", "Get Pro (%@, one-time)", product.displayPrice))
                }
                .buttonStyle(LacquerButtonStyle(fill: Theme.goldDeep, text: .white))
                .disabled(busy)
                .accessibilityIdentifier("paywall.buy")
            } else {
                Text(model.purchases.loadState == .loading ? tr("読み込み中…", "Loading…") : tr("いまは購入できません。通信できる場所で開き直してください。", "Purchases aren't available right now. Try again when you're online."))
                    .font(Theme.label(.footnote))
                    .foregroundStyle(Theme.cream.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            if let message {
                Text(message).font(Theme.label(.footnote, weight: .bold)).foregroundStyle(Theme.goldSoft)
            }
            Button(tr("購入を復元", "Restore purchases")) {
                Task { await model.purchases.restore() }
            }
            .font(Theme.label(.footnote, weight: .bold))
            .foregroundStyle(Theme.cream)
            .frame(minHeight: 44)
            Text(tr("核の遊び（今日の一局・自由に一局・74 品の役・図鑑・買い物メモ）は無料のままです。", "The core game — daily hand, free play, 74 dishes, collection and shopping lists — stays free."))
                .font(Theme.label(.caption2))
                .foregroundStyle(Theme.creamSoft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }
}

// MARK: - 共有

/// 共有カード：赤い看板と、円卓の献立（点と役）。画像にして送る
struct ShareCard: View {
    let record: MenuRecord

    var body: some View {
        VStack(spacing: 14) {
            Signboard {
                SignText(text: tr("献立マージャン", "Menu Mahjong"), size: 24)
            }
            Banquet(melds: record.melds, pair: record.pairKind, animated: false, size: 280)
            Text(record.yaku.joined(separator: " ・ "))
                .font(Theme.label(.footnote, weight: .bold))
                .foregroundStyle(Theme.goldSoft)
                .multilineTextAlignment(.center)
            Text(trf("%d 点", "%d pts", record.points))
                .font(Theme.number(30))
                .foregroundStyle(Theme.cream)
            Text(tr("そろえた役が、今夜の献立になった", "My winning hand became tonight's dinner"))
                .font(Theme.label(.caption, weight: .semibold))
                .foregroundStyle(Theme.creamSoft)
        }
        .padding(24)
        .frame(width: 360)
        .background(Theme.night)
    }
}

struct ShareSheetView: View {
    @Environment(AppModel.self) private var model
    let id: UUID

    var body: some View {
        SheetFrame(title: tr("献立を共有", "Share your menu"), closeID: "main.closeShare") {
            if let record = model.progress.menus.first(where: { $0.id == id }) ?? model.lastRecord {
                ScrollView {
                    VStack(spacing: 16) {
                        ShareCard(record: record)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.rCard, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: Theme.rCard, style: .continuous).strokeBorder(Theme.gold.opacity(0.4), lineWidth: 1))
                        if let image = render(record) {
                            ShareLink(item: image, preview: SharePreview(tr("今夜の献立", "Tonight's menu"), image: image)) {
                                Label(tr("画像で送る", "Share image"), systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(LacquerButtonStyle())
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    private func render(_ record: MenuRecord) -> Image? {
        let renderer = ImageRenderer(content: ShareCard(record: record).environment(\.locale, Lang.locale))
        renderer.scale = 3
        return renderer.uiImage.map { Image(uiImage: $0) }
    }
}
