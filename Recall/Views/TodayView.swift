import SwiftUI

struct TodayView: View {
    @Environment(AppStore.self) private var store
    @AppStorage("dailyGoal") private var dailyGoal = 30
    @AppStorage("newPerDay") private var newPerDay = 15
    @AppStorage("sessionSize") private var sessionSize = 20
    @State private var session: Session?

    var body: some View {
        let queue = store.dailyQueue(limit: sessionSize, newPerDay: newPerDay)
        let due = store.dueRefs().count
        let all = store.allRefs

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    StreakCard(streak: store.streak, studied: store.studied(on:))
                    startCard(queue: queue, due: due)
                    goalCard
                    statsGrid(all)
                    weakSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .background(Palette.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .fullScreenCover(item: $session) { SessionView(session: $0) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "ru_RU"))).capitalizedFirst)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Palette.ink2)
            Text("Сегодня").font(.display).foregroundStyle(Palette.ink)
        }
        .padding(.top, 12)
    }

    private func startCard(queue: [CardRef], due: Int) -> some View {
        let fresh = queue.count - min(due, queue.count)
        let minutes = max(1, Int((Double(queue.count) * 0.4).rounded()))
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(queue.isEmpty ? "На сегодня всё" : "Ежедневная тренировка")
                        .font(.cardTitle)
                        .foregroundStyle(Palette.ink)
                    Text(queue.isEmpty
                         ? "Новые повторения появятся завтра. Можно пройти тест по любой теме или блиц."
                         : "\(queue.count) \(plural(queue.count, "карточка", "карточки", "карточек")) · около \(minutes) мин")
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: queue.isEmpty ? "checkmark.seal.fill" : "sparkles")
                    .font(.system(size: 30))
                    .foregroundStyle(Palette.accent)
                    .accessibilityHidden(true)
            }
            if !queue.isEmpty {
                HStack(spacing: 8) {
                    if due > 0 { Chip(text: "Повторить: \(min(due, queue.count))", icon: "arrow.triangle.2.circlepath", fg: Palette.accent, bg: Palette.accentBg) }
                    if fresh > 0 { Chip(text: "Новых: \(fresh)", icon: "plus", fg: Palette.violet, bg: Palette.violetBg) }
                }
                PrimaryButton(title: "Начать", icon: "play.fill") {
                    session = Session(title: "Тренировка", cards: queue)
                }
            }
        }
        .padding(20)
        .tactile(radius: 24)
    }

    private var goalCard: some View {
        let done = store.answeredToday
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Цель дня", systemImage: "target")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text("\(min(done, dailyGoal)) / \(dailyGoal)")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(done >= dailyGoal ? Palette.good : Palette.ink2)
            }
            ProgressBar(value: Double(done) / Double(max(1, dailyGoal)), tint: done >= dailyGoal ? Palette.good : Palette.accent)
        }
        .padding(18)
        .soft()
    }

    private func statsGrid(_ all: [CardRef]) -> some View {
        let learned = store.count(all, .known) + store.count(all, .mastered)
        let fresh = store.count(all, .new)
        let acc = store.accuracy7
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            StatTile(value: "\(learned)", label: "Выучено", icon: "checkmark.circle", tint: Palette.good)
            StatTile(value: "\(store.count(all, .mastered))", label: "Закреплено", icon: "star", tint: Palette.flame)
            StatTile(value: acc.map { "\(Int(($0 * 100).rounded()))%" } ?? "—", label: "Точность, 7 дней", icon: "scope", tint: Palette.accent)
            StatTile(value: "\(fresh)", label: "Ещё не видел", icon: "tray", tint: Palette.violet)
        }
    }

    @ViewBuilder
    private var weakSection: some View {
        let weak = store.weakTopics
        if !weak.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Слабые места").font(.cardTitle).foregroundStyle(Palette.ink).padding(.top, 8)
                ForEach(weak) { w in
                    Button {
                        let refs = store.refs(w.pack, topic: w.topic.id)
                        session = Session(title: w.topic.title, cards: store.quizQueue(refs, count: 10))
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: w.topic.symbol)
                                .foregroundStyle(Palette.bad)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(Palette.badBg))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(w.topic.title).font(.body.weight(.medium)).foregroundStyle(Palette.ink)
                                Text("\(w.pack.title) · точность \(Int(w.accuracy * 100))%")
                                    .font(.caption).foregroundStyle(Palette.ink2)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Palette.ink2)
                        }
                        .padding(14)
                        .soft(radius: 16)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct StreakCard: View {
    let streak: Int
    let studied: (Date) -> Bool

    var body: some View {
        let cal = Calendar.current
        let today = Date.now
        let weekday = (cal.component(.weekday, from: today) + 5) % 7  // Monday = 0
        let monday = cal.date(byAdding: .day, value: -weekday, to: today)!
        let days = (0..<7).map { cal.date(byAdding: .day, value: $0, to: monday)! }
        let symbols = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]

        HStack(spacing: 16) {
            VStack(spacing: 0) {
                Image(systemName: streak > 0 ? "flame.fill" : "flame")
                    .font(.system(size: 30))
                    .foregroundStyle(Palette.flame)
                Text("\(streak)")
                    .font(.system(.title, design: .serif).weight(.bold))
                    .foregroundStyle(Palette.ink)
            }
            .frame(width: 64, height: 80)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.flameBg))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Стрик \(streak) \(plural(streak, "день", "дня", "дней"))")

            VStack(alignment: .leading, spacing: 10) {
                Text(streak == 0 ? "Начни серию сегодня" : "\(streak) \(plural(streak, "день", "дня", "дней")) подряд")
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { i in
                        let d = days[i]
                        let on = studied(d)
                        let isToday = cal.isDate(d, inSameDayAs: today)
                        VStack(spacing: 4) {
                            Text(symbols[i]).font(.caption2.weight(.medium))
                                .foregroundStyle(isToday ? Palette.ink : Palette.ink2)
                            ZStack {
                                Circle().fill(on ? Palette.flame : Palette.surface2)
                                if on { Image(systemName: "checkmark").font(.caption2.weight(.heavy)).foregroundStyle(Palette.surface) }
                            }
                            .frame(width: 24, height: 24)
                            .overlay(Circle().strokeBorder(isToday && !on ? Palette.flame : .clear, lineWidth: 1.5))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(16)
        .soft()
    }
}

struct StatTile: View {
    let value: String
    let label: String
    let icon: String
    let tint: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).foregroundStyle(tint).font(.title3)
            Text(value).font(.system(.title2, design: .serif).weight(.bold)).foregroundStyle(Palette.ink)
                .monospacedDigit()
            Text(label).font(.caption).foregroundStyle(Palette.ink2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .soft(radius: 18)
        .accessibilityElement(children: .combine)
    }
}

extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
