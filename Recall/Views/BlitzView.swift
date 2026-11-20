import SwiftUI

/// Experimental mode: 60 seconds, a question with one candidate answer, swipe right if it is correct.
/// Goal: more short daily sessions (sessions per day, D7 retention of the streak). Not part of SRS.
struct BlitzView: View {
    @Environment(AppStore.self) private var store
    @State private var game: BlitzGame?

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text("Блиц").font(.display).foregroundStyle(Palette.ink)
                        Chip(text: "Эксперимент", icon: "flask", fg: Palette.violet, bg: Palette.violetBg)
                    }
                    .padding(.top, 12)
                    Text("60 секунд. Вопрос и один ответ. Верный — свайп вправо, нет — влево. Серия без ошибок даёт множитель.")
                        .font(.body)
                        .foregroundStyle(Palette.ink2)
                        .fixedSize(horizontal: false, vertical: true)

                    BlitzIllustration()
                        .frame(maxWidth: .infinity)
                        .frame(height: 260)

                    HStack {
                        StatTile(value: "\(store.progress.blitzBest)", label: "Рекорд", icon: "trophy", tint: Palette.flame)
                        StatTile(value: "\(store.allRefs.filter { $0.card.type == .choice }.count)", label: "Вопросов в колоде", icon: "rectangle.stack", tint: Palette.accent)
                    }
                    Spacer()
                    PrimaryButton(title: "Поехали", icon: "bolt.fill", fill: Palette.violet, fg: Palette.surface) {
                        game = BlitzGame(refs: store.allRefs)
                    }
                    .disabled(store.allRefs.isEmpty)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .fullScreenCover(item: $game) { BlitzPlay(game: $0) }
    }
}

struct BlitzIllustration: View {
    @State private var tilt = false
    var body: some View {
        ZStack {
            ForEach(0..<3) { i in
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(i == 2 ? Palette.surface : Palette.surface2)
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Palette.line, lineWidth: 1.5))
                    .frame(width: 190, height: 230)
                    .rotationEffect(.degrees(Double(i - 1) * 7 + (i == 2 && tilt ? 9 : 0)))
                    .offset(x: i == 2 && tilt ? 26 : CGFloat(i - 1) * 10)
            }
            VStack(spacing: 12) {
                Image(systemName: "bolt.fill").font(.system(size: 44)).foregroundStyle(Palette.violet)
                Text("Верно?").font(.cardTitle).foregroundStyle(Palette.ink)
            }
            .rotationEffect(.degrees(tilt ? 9 : 7))
            .offset(x: tilt ? 26 : 10)
            HStack {
                Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.bad)
                Spacer()
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.good)
            }
            .font(.system(size: 34))
            .padding(.horizontal, 20)
        }
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { tilt = true }
        }
    }
}

@Observable
final class BlitzGame: Identifiable {
    struct Item { let ref: CardRef; let shown: String; let isRight: Bool }
    let id = UUID()
    private var pool: [CardRef]
    private(set) var item: Item?
    private(set) var score = 0
    private(set) var answered = 0
    private(set) var streak = 0
    private(set) var lastWrong: Item?
    let endsAt = Date.now.addingTimeInterval(60)

    init(refs: [CardRef]) {
        pool = refs.filter { $0.card.type == .choice && ($0.card.options?.count ?? 0) >= 2 }.shuffled()
        nextItem()
    }

    var multiplier: Int { streak >= 10 ? 3 : streak >= 5 ? 2 : 1 }

    private func nextItem() {
        guard !pool.isEmpty else { item = nil; return }
        let ref = pool.removeFirst()
        let opts = ref.card.options ?? []
        let a = ref.card.answer ?? 0
        let right = Bool.random()
        let wrongs = opts.indices.filter { $0 != a }
        let shown = right || wrongs.isEmpty ? opts[a] : opts[wrongs.randomElement()!]
        item = Item(ref: ref, shown: shown, isRight: right || wrongs.isEmpty)
    }

    @discardableResult
    func answer(_ yes: Bool) -> Bool {
        guard let item else { return false }
        answered += 1
        let ok = yes == item.isRight
        if ok { streak += 1; score += multiplier; lastWrong = nil } else { streak = 0; lastWrong = item }
        nextItem()
        return ok
    }
}

struct BlitzPlay: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var game: BlitzGame
    @State private var drag: CGSize = .zero
    @State private var over = false
    @State private var flash: Color?

    var body: some View {
        ZStack {
            (flash ?? Palette.bg).ignoresSafeArea().animation(.easeOut(duration: 0.25), value: flash)
            if over || game.item == nil {
                finish
            } else {
                TimelineView(.periodic(from: .now, by: 0.1)) { ctx in
                    let left = max(0, game.endsAt.timeIntervalSince(ctx.date))
                    play(left: left)
                        .onChange(of: left == 0) { _, done in if done { end() } }
                }
            }
        }
    }

    private func play(left: Double) -> some View {
        VStack(spacing: 18) {
            HStack {
                Button { end() } label: {
                    Image(systemName: "xmark").font(.body.weight(.semibold)).foregroundStyle(Palette.ink)
                        .frame(width: 44, height: 44).background(Circle().fill(Palette.surface))
                }
                .accessibilityLabel("Закончить")
                .accessibilityIdentifier("close")
                Spacer()
                Text("\(Int(left.rounded(.up)))")
                    .font(.system(.title, design: .serif).weight(.bold).monospacedDigit())
                    .foregroundStyle(left < 10 ? Palette.bad : Palette.ink)
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(game.score)").font(.title3.weight(.bold).monospacedDigit()).foregroundStyle(Palette.ink)
                    if game.multiplier > 1 {
                        Text("×\(game.multiplier)").font(.caption.weight(.heavy)).foregroundStyle(Palette.violet)
                    }
                }
                .frame(width: 44, alignment: .trailing)
            }
            ProgressBar(value: left / 60, tint: Palette.violet, height: 6)

            if let item = game.item {
                ZStack {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(item.ref.card.q).font(.body).foregroundStyle(Palette.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                        Divider().overlay(Palette.line.opacity(0.3))
                        Text(item.shown).font(.question).foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(22)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .tactile(radius: 28)
                    stamp
                }
                .frame(maxHeight: 440)
                .offset(x: drag.width, y: drag.height * 0.2)
                .rotationEffect(.degrees(Double(drag.width) / 18))
                .gesture(DragGesture()
                    .onChanged { drag = $0.translation }
                    .onEnded { v in
                        if abs(v.translation.width) > 110 { answer(v.translation.width > 0) }
                        else { withAnimation(.spring) { drag = .zero } }
                    })
                .id(game.answered)
                .transition(.asymmetric(insertion: .scale(scale: 0.92).combined(with: .opacity), removal: .identity))
            }
            Spacer(minLength: 0)
            HStack(spacing: 14) {
                PrimaryButton(title: "Нет", icon: "xmark", fill: Palette.badBg, fg: Palette.bad) { answer(false) }
                PrimaryButton(title: "Верно", icon: "checkmark", fill: Palette.goodBg, fg: Palette.good) { answer(true) }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    @ViewBuilder private var stamp: some View {
        let w = Double(drag.width)
        if abs(w) > 30 {
            let yes = w > 0
            let tint: Color = yes ? Palette.good : Palette.bad
            let alpha: Double = min(1, (abs(w) - 30) / 80)
            let angle: Double = yes ? -12 : 12
            Text(yes ? "Верно" : "Нет")
                .font(Font.title.weight(.black))
                .foregroundStyle(tint)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(tint, lineWidth: 3))
                .rotationEffect(.degrees(angle))
                .opacity(alpha)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: yes ? .topLeading : .topTrailing)
                .padding(24)
        }
    }

    private func answer(_ yes: Bool) {
        let ok = game.answer(yes)
        ok ? Haptics.success() : Haptics.error()
        flash = ok ? Palette.goodBg : Palette.badBg
        drag = .zero
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { flash = nil }
    }

    private func end() {
        guard !over else { return }
        over = true
        store.recordBlitz(score: game.score, answered: game.answered)
    }

    private var finish: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "bolt.fill").font(.system(size: 54)).foregroundStyle(Palette.violet)
            Text("\(game.score)").font(.system(size: 72, weight: .bold, design: .serif)).foregroundStyle(Palette.ink)
            Text(game.score >= store.progress.blitzBest && game.score > 0 ? "Новый рекорд" : "Рекорд: \(store.progress.blitzBest)")
                .font(.headline).foregroundStyle(Palette.ink2)
            Text("Ответов: \(game.answered)").font(.subheadline).foregroundStyle(Palette.ink2)
            if let w = game.lastWrong {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Последняя ошибка").font(.caption.weight(.semibold)).foregroundStyle(Palette.bad)
                    Text(w.ref.card.q).font(.subheadline).foregroundStyle(Palette.ink2)
                    Text(w.ref.card.correctText).font(.body.weight(.semibold)).foregroundStyle(Palette.good)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .soft()
            }
            Spacer()
            PrimaryButton(title: "Ещё раз", icon: "arrow.counterclockwise", fill: Palette.violet, fg: Palette.surface) {
                game = BlitzGame(refs: store.allRefs)
                over = false
            }
            PrimaryButton(title: "Готово", fill: Palette.surface, fg: Palette.ink) { dismiss() }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
}
