import SwiftUI

@main
struct RecallApp: App {
    @State private var store: AppStore
    @AppStorage("theme") private var theme = 0

    init() {
        // Launch arguments for screenshots and UI checks:
        // -demo seeds progress, -tab N opens a tab, -theme 1|2 forces light|dark (UserDefaults argument domain).
        if ProcessInfo.processInfo.arguments.contains("-demo") { DemoData.seed() }
        _store = State(initialValue: AppStore())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .tint(Palette.accent)
                .environment(\.locale, Locale(identifier: "ru_RU"))
                .preferredColorScheme(theme == 1 ? .light : theme == 2 ? .dark : nil)
        }
    }
}

struct RootView: View {
    @State private var tab: Int = {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-tab"), i + 1 < args.count { return Int(args[i + 1]) ?? 0 }
        return 0
    }()

    var body: some View {
        TabView(selection: $tab) {
            TodayView()
                .tabItem { Label("Сегодня", systemImage: "sun.max") }.tag(0)
            LibraryView()
                .tabItem { Label("Темы", systemImage: "books.vertical") }.tag(1)
            BlitzView()
                .tabItem { Label("Блиц", systemImage: "bolt") }.tag(2)
            SettingsView()
                .tabItem { Label("Настройки", systemImage: "gearshape") }.tag(3)
        }
    }
}

/// Writes a believable progress file so screenshots show a lived-in app.
enum DemoData {
    static func seed() {
        let store = AppStore(preview: true)
        let cal = Calendar.current
        var p = Progress()
        for (i, ref) in store.allRefs.enumerated() where i % 3 != 0 {
            var s = CardState()
            s.seen = 1 + i % 4
            s.correct = s.seen - (i % 5 == 0 ? 1 : 0)
            s.lapses = i % 7 == 0 ? 2 : 0
            s.interval = Double([1, 3, 8, 25][i % 4])
            s.reps = 2
            s.due = i % 4 == 0 ? .now.addingTimeInterval(-3600) : .now.addingTimeInterval(86400 * s.interval)
            s.last = .now
            p.cards[ref.key] = s
        }
        for d in 0..<5 {
            let k = AppStore.dayKey(cal.date(byAdding: .day, value: -d, to: .now)!)
            p.days[k] = d == 0 ? 18 : 25
            p.correctDays[k] = d == 0 ? 15 : 21
        }
        p.blitzBest = 27
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("progress.json")
        try? JSONEncoder().encode(p).write(to: url)
    }
}
