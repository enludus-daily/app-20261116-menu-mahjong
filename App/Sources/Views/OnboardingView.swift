import SwiftUI

/// 最初の案内（3 ページ）：3 枚で 1 品 → 4 品＋主食で和了り → 献立と買い物メモが残る
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var page = 0
    @State private var joined = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 18) {
            Signboard {
                SignText(text: tr("献立マージャン", "Menu Mahjong"), size: 26)
            }
            .padding(.top, 16)
            Spacer(minLength: 0)
            Group {
                switch page {
                case 0: pageOne
                case 1: pageTwo
                default: pageThree
                }
            }
            .id(page)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule().fill(i == page ? Theme.gold : Theme.cream.opacity(0.25))
                        .frame(width: i == page ? 22 : 8, height: 8)
                }
            }
            .accessibilityHidden(true)
            Group {
                if page < 2 {
                    Button(tr("つぎへ", "Next")) {
                        model.press()
                        withAnimation(.easeOut(duration: 0.3)) { page += 1 }
                    }
                    .accessibilityIdentifier("main.next")
                } else {
                    Button(tr("卓につく", "Take a seat")) {
                        model.press()
                        withAnimation(.easeOut(duration: 0.35)) { model.onboarded = true }
                    }
                    .accessibilityIdentifier("main.start")
                }
            }
            .buttonStyle(LacquerButtonStyle())
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .background(NightBackground())
        .onChange(of: page) { _, _ in animateJoin() }
        .onAppear { animateJoin() }
    }

    private func animateJoin() {
        joined = false
        if reduceMotion || model.still { joined = true; return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.65).delay(0.6)) { joined = true }
    }

    private func k(_ id: String) -> Int { Kitchen.ingredients.first { $0.id == id }?.index ?? 0 }

    // 1. 3 枚で 1 品
    private var pageOne: some View {
        VStack(spacing: 20) {
            HStack(spacing: joined ? 2 : 16) {
                ForEach(["pork", "ginger", "soy"], id: \.self) { id in
                    TileView(kind: k(id), width: 58, showName: true)
                }
            }
            Image(systemName: "arrow.down")
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(Theme.gold)
            ZStack {
                Plate(size: 110)
                Text(tr("生姜焼き", "Ginger pork"))
                    .font(Theme.label(.footnote, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 70)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
                Steam(height: 34, delay: 0.9, animated: !model.still).offset(y: -62)
            }
            .scaleEffect(joined ? 1 : 0.7)
            .opacity(joined ? 1 : 0.3)
            text(tr("食材の牌を 3 枚そろえると、1 品の料理になる", "Three ingredient tiles make one dish"),
                 tr("豚・生姜・しょうゆで「豚の生姜焼き」。料理の役は 70 品以上。同じ食材 3 枚は「づくし」。", "Pork + ginger + soy = Ginger Pork. Over 70 dishes to find. Three of a kind is an \"All-in\" plate."))
        }
    }

    // 2. 4 品＋主食で和了り
    private var pageTwo: some View {
        VStack(spacing: 20) {
            Banquet(melds: [Meld(kind: .recipe(0)), Meld(kind: .recipe(2)), Meld(kind: .recipe(29)), Meld(kind: .recipe(56))], pair: k("rice"), animated: !model.still, size: 250)
            text(tr("4 品と、同じ 2 枚の主食で和了り", "4 dishes + a pair (your staple) wins"),
                 tr("1 枚引いて 1 枚捨てる。料理になりそうな牌を残そう。相手 3 人より先にそろえたら勝ち。", "Draw one, discard one. Keep tiles that cook together and beat three rival chefs to dinner."))
        }
    }

    // 3. 献立と買い物メモ
    private var pageThree: some View {
        VStack(spacing: 20) {
            OrderSlip(title: tr("今夜の御献立", "Tonight's Menu")) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach([0, 2, 29, 56], id: \.self) { r in
                        HStack(spacing: 6) {
                            CuisineMark(cuisine: Kitchen.recipes[r].cuisine, size: 16)
                            Text(Kitchen.recipes[r].name).font(Theme.label(.footnote, weight: .bold)).foregroundStyle(Theme.ink)
                        }
                    }
                    Text(tr("買い物メモ：豚肉・鶏肉・ひき肉・卵・玉ねぎ…", "Shopping: pork, chicken, mince, eggs, onion…"))
                        .font(Theme.label(.caption))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            .frame(maxWidth: 320)
            .rotationEffect(.degrees(joined ? -2 : 0))
            text(tr("和了ると、今夜の献立と買い物メモが残る", "A win leaves tonight's menu and a shopping list"),
                 tr("作った料理は図鑑に集まる。記録はこの端末の中だけに保存し、外には送りません。", "Dishes fill your collection. Everything stays on this device — nothing is sent anywhere."))
        }
    }

    private func text(_ title: String, _ body: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(Theme.label(.title3, weight: .heavy))
                .foregroundStyle(Theme.goldSoft)
                .multilineTextAlignment(.center)
            Text(body)
                .font(Theme.label(.subheadline, weight: .medium))
                .foregroundStyle(Theme.cream.opacity(0.88))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
