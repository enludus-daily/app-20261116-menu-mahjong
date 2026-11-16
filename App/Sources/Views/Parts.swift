import SwiftUI

// MARK: - 牌

/// 食材の牌：象牙の面に字を彫り、下に翡翠色の背の厚みを見せる（立体の麻雀牌）
struct TileView: View {
    let kind: Int
    var width: CGFloat = 30
    var selected = false
    /// 強く見せる（引いた牌・待ちの牌）
    var glow = false
    /// 名前を下に小さく出す（大きい牌だけ）
    var showName = false

    private var ingredient: Ingredient { Kitchen.ingredients[kind] }
    private var height: CGFloat { width * 1.36 }
    private var depth: CGFloat { max(2.5, width * 0.12) }

    var body: some View {
        let r = width * Theme.rTile
        ZStack(alignment: .top) {
            // 背（厚み）
            RoundedRectangle(cornerRadius: r, style: .continuous)
                .fill(LinearGradient(colors: [Theme.jade, Theme.jadeDeep], startPoint: .top, endPoint: .bottom))
                .frame(width: width, height: height)
                .offset(y: depth)
            // 面
            RoundedRectangle(cornerRadius: r, style: .continuous)
                .fill(LinearGradient(colors: [Theme.ivory, Theme.ivoryShade], startPoint: .top, endPoint: .bottom))
                .frame(width: width, height: height)
                .overlay(
                    RoundedRectangle(cornerRadius: r * 0.8, style: .continuous)
                        .strokeBorder(Theme.ivoryShade.opacity(0.9), lineWidth: max(0.6, width * 0.025))
                        .padding(width * 0.07)
                )
                .overlay {
                    VStack(spacing: 0) {
                        Text(ingredient.glyph)
                            .font(Theme.carved(width * (showName ? 0.56 : 0.66)))
                            .foregroundStyle(Theme.inkFor(ingredient.category))
                            // 彫った字の影（下に白、上に濃い）
                            .shadow(color: .white.opacity(0.8), radius: 0, x: 0, y: max(0.5, width * 0.02))
                        if showName {
                            Text(ingredient.name)
                                .font(.system(size: max(7, width * 0.17), weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.inkSoft)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .padding(.horizontal, 2)
                        }
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: r, style: .continuous)
                        .strokeBorder(glow ? Theme.gold : .clear, lineWidth: max(1.5, width * 0.07))
                )
        }
        .frame(width: width, height: height + depth, alignment: .top)
        .shadow(color: .black.opacity(selected ? 0.4 : 0.25), radius: selected ? 6 : 2, y: selected ? 5 : 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ingredient.name)
    }
}

/// 伏せた牌（相手の手・山）
struct TileBack: View {
    var width: CGFloat = 12
    var body: some View {
        RoundedRectangle(cornerRadius: width * 0.18, style: .continuous)
            .fill(LinearGradient(colors: [Theme.jade, Theme.jadeDeep], startPoint: .top, endPoint: .bottom))
            .overlay(RoundedRectangle(cornerRadius: width * 0.18, style: .continuous).strokeBorder(.white.opacity(0.18), lineWidth: 0.6))
            .frame(width: width, height: width * 1.36)
            .accessibilityHidden(true)
    }
}

// MARK: - 卓布と夜の店

/// 緑の卓布（細かい織り目と、縁の暗がり）
struct FeltBackground: View {
    var body: some View {
        ZStack {
            Theme.felt
            Canvas { ctx, size in
                var path = Path()
                let step: CGFloat = 5
                var x: CGFloat = -size.height
                while x < size.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x + size.height, y: size.height))
                    x += step
                }
                ctx.stroke(path, with: .color(.white.opacity(0.035)), lineWidth: 0.6)
            }
            RadialGradient(colors: [.clear, Theme.feltDeep.opacity(0.85)], center: .center, startRadius: 80, endRadius: 520)
        }
        .accessibilityHidden(true)
    }
}

/// 夜の店の地（焦げ茶の木と、上から看板の灯り）
struct NightBackground: View {
    var body: some View {
        ZStack {
            Theme.night
            RadialGradient(colors: [Theme.lacquer.opacity(0.28), .clear], center: .top, startRadius: 10, endRadius: 420)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

// MARK: - 看板

/// 赤い漆に金の二重の縁の看板
struct Signboard<Content: View>: View {
    var compact = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, compact ? 14 : 20)
            .padding(.vertical, compact ? 8 : 12)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient(colors: [Theme.lacquerSoft, Theme.lacquer, Theme.lacquerDeep], startPoint: .top, endPoint: .bottom))
            )
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.gold, lineWidth: 2.5))
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(Theme.gold.opacity(0.55), lineWidth: 1).padding(5))
            .shadow(color: Theme.lacquer.opacity(0.45), radius: 14, y: 4)
    }
}

/// 看板の題字（金の字に、赤い縁取りの影）
struct SignText: View {
    let text: String
    var size: CGFloat = 30
    var body: some View {
        Text(text)
            .font(Theme.sign(size))
            .kerning(size * 0.06)
            .foregroundStyle(LinearGradient(colors: [Theme.goldSoft, Theme.gold, Theme.goldDeep], startPoint: .top, endPoint: .bottom))
            .shadow(color: Theme.lacquerDeep, radius: 0, x: 0, y: 2)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }
}

// MARK: - ボタン

/// 漆塗りの札のボタン（押すと沈む）
struct LacquerButtonStyle: ButtonStyle {
    var fill: Color = Theme.lacquer
    var text: Color = Theme.goldSoft
    var height: CGFloat = 52

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.label(.headline, weight: .heavy))
            .foregroundStyle(text)
            .frame(maxWidth: .infinity, minHeight: height)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(fill)
                    .shadow(color: .black.opacity(0.45), radius: 0, y: configuration.isPressed ? 1 : 4)
            )
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.gold.opacity(0.8), lineWidth: 1.5))
            .offset(y: configuration.isPressed ? 3 : 0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// 漆塗りの札の見た目（押した感じはボタン側で付けない。ホームの主なボタン用）
struct LacquerLook: ViewModifier {
    var fill: Color = Theme.lacquer
    var text: Color = Theme.goldSoft
    var height: CGFloat = 52

    func body(content: Content) -> some View {
        content
            .font(Theme.label(.headline, weight: .heavy))
            .foregroundStyle(text)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(fill)
                    .shadow(color: .black.opacity(0.45), radius: 0, y: 4)
            )
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.gold.opacity(0.8), lineWidth: 1.5))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// 漆塗りの札の文字
struct LacquerLabel: View {
    let title: String
    var body: some View {
        Text(title)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 10)
            .modifier(LacquerLook())
    }
}

/// 小さな丸い札（設定・閉じるなど）
struct ChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.label(.subheadline, weight: .bold))
            .foregroundStyle(Theme.cream)
            .padding(.horizontal, 12)
            .frame(minWidth: 44, minHeight: 44)
            .background(Capsule().fill(Theme.nightRaised))
            .overlay(Capsule().strokeBorder(Theme.gold.opacity(0.45), lineWidth: 1))
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - 料理の皿と湯気

/// 中華の皿：白い皿に藍の縁の模様（雷文の代わりに点線の輪）
struct Plate: View {
    var size: CGFloat = 90
    var body: some View {
        ZStack {
            Circle().fill(.white)
            Circle().strokeBorder(Color(hex: 0x2B4E9B), lineWidth: size * 0.045).padding(size * 0.04)
            Circle().strokeBorder(Color(hex: 0x2B4E9B).opacity(0.75), style: StrokeStyle(lineWidth: size * 0.03, dash: [size * 0.035, size * 0.03])).padding(size * 0.11)
            Circle().fill(Color(hex: 0xF5F1EA)).padding(size * 0.17)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.35), radius: 4, y: 3)
        .accessibilityHidden(true)
    }
}

/// 湯気：ゆらぐ線が上へのぼって消える（1 回だけ。止める設定・撮影では止まった絵）
struct Steam: View {
    var height: CGFloat = 36
    var delay: Double = 0
    var animated = true
    @State private var risen = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: height * 0.18) {
            ForEach(0..<3, id: \.self) { i in
                SteamLine()
                    .stroke(.white.opacity(0.75), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                    .frame(width: height * 0.22, height: height * (i == 1 ? 1 : 0.8))
            }
        }
        .offset(y: risen ? -height * 0.35 : 0)
        .opacity(still ? 0.75 : (risen ? 0.15 : 0.85))
        .onAppear {
            guard !still else { return }
            withAnimation(.easeOut(duration: 2.6).delay(delay)) { risen = true }
        }
        .accessibilityHidden(true)
    }

    private var still: Bool { !animated || reduceMotion }
}

struct SteamLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addCurve(to: CGPoint(x: rect.midX, y: rect.minY),
                   control1: CGPoint(x: rect.minX - rect.width * 0.4, y: rect.maxY - rect.height * 0.35),
                   control2: CGPoint(x: rect.maxX + rect.width * 0.4, y: rect.minY + rect.height * 0.35))
        return p
    }
}

// MARK: - 伝票

/// 中華料理店の伝票：白い紙に赤い罫線と、上の「御献立」の帯
struct OrderSlip<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title)
                    .font(Theme.sign(15))
                    .kerning(1.5)
                    .foregroundStyle(Theme.lacquer)
                Spacer()
                Text("No.\u{2009}011")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.slipRule)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)
            Rectangle().fill(Theme.slipRule).frame(height: 1.5)
            content
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(
            // 罫線は Canvas で、伝票と同じ大きさにだけ描く。
            // 2026-11-16：罫線を 40 本の Rectangle で並べたら背景が伝票より縦に大きくなり、上下にはみ出した（clipped は見た目だけで、
            // 当たり判定は残る）。見えない背景が上の「今日の一局を打つ」などのボタンを覆い、押しても動かなかった
            Canvas { ctx, size in
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Theme.slip))
                var y: CGFloat = 62
                while y < size.height {
                    ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 0.7)), with: .color(Theme.slipRule.opacity(0.18)))
                    y += 23.7
                }
            }
            .allowsHitTesting(false)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
    }
}

/// 料理の系統の小さな判（和・中・洋）
struct CuisineMark: View {
    let cuisine: Cuisine?
    var size: CGFloat = 20
    var body: some View {
        Text(cuisine?.mark ?? "尽")
            .font(Theme.carved(size * 0.62))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous).fill(cuisine.map(Theme.cuisine) ?? Theme.goldDeep))
            .accessibilityHidden(true)
    }
}

/// 連続日数のちょうちん
struct Lantern: View {
    let count: Int
    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Theme.goldDeep).frame(width: 14, height: 3)
            ZStack {
                Ellipse().fill(LinearGradient(colors: [Theme.lacquerSoft, Theme.lacquer], startPoint: .top, endPoint: .bottom))
                VStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { _ in Rectangle().fill(Theme.lacquerDeep.opacity(0.4)).frame(height: 0.8) }
                }
                .padding(.horizontal, 6)
                Text("\(count)")
                    .font(Theme.number(16))
                    .foregroundStyle(Theme.goldSoft)
                    .contentTransition(.numericText())
            }
            .frame(width: 38, height: 44)
            Rectangle().fill(Theme.goldDeep).frame(width: 14, height: 3)
        }
        .shadow(color: Theme.lacquer.opacity(0.6), radius: 10)
    }
}
