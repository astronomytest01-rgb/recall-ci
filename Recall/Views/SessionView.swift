import SwiftUI

struct SessionView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var session: Session
    @State private var showResult = false
    @State private var confirmClose = false

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()
            if showResult || session.isDone {
                ResultView(session: session) { mistakes in
                    session = Session(title: "Работа над ошибками", cards: mistakes.shuffled())
                    showResult = false
                } done: { dismiss() }
                .transition(.opacity)
            } else if let ref = session.current {
                VStack(spacing: 0) {
                    header
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            QuestionBlock(ref: ref, retry: session.isRetry)
                            if ref.card.type == .choice {
                                ChoiceOptions(session: session)
                            } else if session.phase == .revealed {
                                AnswerBlock(text: ref.card.correctText, tint: Palette.accent, bg: Palette.accentBg)
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                            if session.phase == .revealed {
                                Explanation(card: ref.card)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                    .scrollIndicators(.hidden)
                    .id(session.index)
                    footer(ref)
                }
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: session.phase)
        .animation(.spring(duration: 0.35), value: session.index)
        .confirmationDialog("Закончить сессию?", isPresented: $confirmClose, titleVisibility: .visible) {
            Button("Показать итог") { showResult = true }
            Button("Выйти без итога", role: .destructive) { dismiss() }
        } message: {
            Text("Ответы уже сохранены.")
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Button {
                if session.outcomes.isEmpty { dismiss() } else { confirmClose = true }
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Palette.surface))
            }
            .accessibilityLabel("Закрыть")
            .accessibilityIdentifier("close")
            ProgressBar(value: session.progress, height: 10)
            Text("\(min(session.index + 1, session.total))/\(session.total)")
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(Palette.ink2)
                .frame(minWidth: 44, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func footer(_ ref: CardRef) -> some View {
        VStack(spacing: 10) {
            switch (ref.card.type, session.phase) {
            case (.choice, .asking):
                Text("Выбери ответ")
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink2)
                    .frame(height: 54)
            case (.choice, .revealed):
                if session.pickedCorrect {
                    HStack(spacing: 10) {
                        Button { next(.hard) } label: {
                            Text("Угадал")
                                .font(.headline)
                                .foregroundStyle(Palette.ink)
                                .frame(maxWidth: .infinity, minHeight: 54)
                        }
                        .buttonStyle(PressStyle(fill: Palette.surface, radius: 16))
                        .accessibilityIdentifier("Угадал")
                        .frame(maxWidth: 120)
                        PrimaryButton(title: "Дальше", icon: "arrow.right", fill: Palette.good) { next(.good) }
                    }
                } else {
                    PrimaryButton(title: "Понятно, дальше", icon: "arrow.right", fill: Palette.ink, fg: Palette.bg) { next(.again) }
                }
            case (.flash, .asking):
                PrimaryButton(title: "Показать ответ", icon: "eye") {
                    Haptics.tap()
                    session.reveal()
                }
            case (.flash, .revealed):
                GradeBar(state: store.state(ref)) { next($0) }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Palette.bg)
    }

    private func next(_ grade: Grade) {
        Haptics.tap()
        if let (ref, g) = session.advance(grade: grade) {
            store.record(ref, grade: g)
        }
    }
}

// MARK: Pieces

struct QuestionBlock: View {
    let ref: CardRef
    var retry = false
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Chip(text: ref.topicTitle.isEmpty ? ref.packTitle : ref.topicTitle)
                if ref.card.type == .flash { Chip(text: "Вспомни", icon: "brain", fg: Palette.violet, bg: Palette.violetBg) }
                if retry { Chip(text: "Ещё раз", icon: "arrow.counterclockwise", fg: Palette.flame, bg: Palette.flameBg) }
            }
            Text(ref.card.q)
                .font(.question)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .frame(minHeight: 160, alignment: .topLeading)
        .tactile(radius: 24)
    }
}

struct ChoiceOptions: View {
    @Bindable var session: Session

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(session.options.enumerated()), id: \.offset) { i, opt in
                Button {
                    if session.pick(i) { Haptics.success() } else { Haptics.error() }
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(opt.text)
                            .font(.body.weight(.medium))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        if let icon = icon(i, opt) {
                            Image(systemName: icon).font(.body.weight(.bold))
                        }
                    }
                    .foregroundStyle(fg(i, opt))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 15)
                    .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                }
                .buttonStyle(PressStyle(fill: fill(i, opt), stroke: stroke(i, opt), radius: 16))
                .disabled(session.phase == .revealed)
                .accessibilityIdentifier("option-\(i)")
                .accessibilityHint(session.phase == .revealed && opt.correct ? "Правильный ответ" : "")
            }
        }
    }

    private var revealed: Bool { session.phase == .revealed }
    private func icon(_ i: Int, _ o: Session.Option) -> String? {
        guard revealed else { return nil }
        if o.correct { return "checkmark" }
        return session.picked == i ? "xmark" : nil
    }
    private func fill(_ i: Int, _ o: Session.Option) -> Color {
        guard revealed else { return Palette.surface }
        if o.correct { return Palette.goodBg }
        return session.picked == i ? Palette.badBg : Palette.surface
    }
    private func stroke(_ i: Int, _ o: Session.Option) -> Color {
        guard revealed else { return Palette.line }
        if o.correct { return Palette.good }
        return session.picked == i ? Palette.bad : Palette.ink2.opacity(0.35)
    }
    private func fg(_ i: Int, _ o: Session.Option) -> Color {
        guard revealed else { return Palette.ink }
        if o.correct { return Palette.good }
        return session.picked == i ? Palette.bad : Palette.ink2
    }
}

struct AnswerBlock: View {
    let text: String
    var tint: Color
    var bg: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Ответ", systemImage: "lightbulb")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
            Text(text)
                .font(.body)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .soft(bg)
    }
}

struct Explanation: View {
    let card: Card
    var body: some View {
        if card.explain?.isEmpty == false || card.source?.isEmpty == false {
            VStack(alignment: .leading, spacing: 10) {
                if let e = card.explain, !e.isEmpty {
                    Text(e)
                        .font(.callout)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let s = card.source, !s.isEmpty {
                    Label(s, systemImage: "doc.text")
                        .font(.caption)
                        .foregroundStyle(Palette.ink2)
                        .lineLimit(2)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .soft(Palette.surface2)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

struct GradeBar: View {
    let state: CardState
    let onGrade: (Grade) -> Void
    var body: some View {
        HStack(spacing: 8) {
            ForEach(Grade.allCases, id: \.self) { g in
                Button { onGrade(g) } label: {
                    VStack(spacing: 2) {
                        Text(g.title).font(.subheadline.weight(.semibold))
                        Text(Scheduler.hint(g, state)).font(.caption2.monospacedDigit()).opacity(0.75)
                    }
                    .foregroundStyle(color(g))
                    .frame(maxWidth: .infinity, minHeight: 54)
                }
                .buttonStyle(PressStyle(fill: bg(g), stroke: color(g), radius: 14))
                .accessibilityIdentifier("grade-\(g.rawValue)")
            }
        }
    }
    private func color(_ g: Grade) -> Color {
        switch g {
        case .again: Palette.bad
        case .hard: Palette.flame
        case .good: Palette.good
        case .easy: Palette.accent
        }
    }
    private func bg(_ g: Grade) -> Color {
        switch g {
        case .again: Palette.badBg
        case .hard: Palette.flameBg
        case .good: Palette.goodBg
        case .easy: Palette.accentBg
        }
    }
}

// MARK: Result

struct ResultView: View {
    let session: Session
    let retry: ([CardRef]) -> Void
    let done: () -> Void

    var body: some View {
        let total = session.outcomes.count
        let ok = session.correctCount
        let share = total == 0 ? 0 : Double(ok) / Double(total)
        ScrollView {
            VStack(spacing: 24) {
                ZStack {
                    Circle().stroke(Palette.surface2, lineWidth: 14)
                    Circle().trim(from: 0, to: share)
                        .stroke(share >= 0.8 ? Palette.good : share >= 0.5 ? Palette.flame : Palette.bad,
                                style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 2) {
                        Text("\(Int((share * 100).rounded()))%")
                            .font(.system(size: 44, weight: .bold, design: .serif))
                            .foregroundStyle(Palette.ink)
                        Text("\(ok) из \(total)").font(.subheadline).foregroundStyle(Palette.ink2)
                    }
                }
                .frame(width: 180, height: 180)
                .padding(.top, 24)

                VStack(spacing: 6) {
                    Text(headline(share)).font(.display).foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.center)
                    Text(durationText).font(.subheadline).foregroundStyle(Palette.ink2)
                }

                if !session.mistakes.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ошибки").font(.cardTitle).foregroundStyle(Palette.ink)
                        ForEach(session.mistakes) { ref in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(ref.card.q).font(.subheadline).foregroundStyle(Palette.ink2)
                                Text(ref.card.correctText).font(.body.weight(.semibold)).foregroundStyle(Palette.good)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .soft(Palette.surface, radius: 14)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                if !session.mistakes.isEmpty {
                    PrimaryButton(title: "Прогнать ошибки ещё раз", icon: "arrow.counterclockwise",
                                  fill: Palette.surface, fg: Palette.ink) { retry(session.mistakes) }
                }
                PrimaryButton(title: "Готово") { done() }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .background(Palette.bg)
        }
        .onAppear { if share >= 0.8 { Haptics.success() } }
    }

    private func headline(_ s: Double) -> String {
        switch s {
        case 0.9...: "Отлично"
        case 0.7..<0.9: "Хороший темп"
        case 0.5..<0.7: "Уже лучше"
        default: "Есть что подтянуть"
        }
    }

    private var durationText: String {
        let m = Int(session.duration) / 60, s = Int(session.duration) % 60
        return m > 0 ? "\(m) мин \(s) с" : "\(s) с"
    }
}
