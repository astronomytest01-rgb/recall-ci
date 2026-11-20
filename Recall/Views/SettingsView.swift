import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @AppStorage("theme") private var theme = 0
    @AppStorage("dailyGoal") private var dailyGoal = 30
    @AppStorage("newPerDay") private var newPerDay = 15
    @AppStorage("sessionSize") private var sessionSize = 20
    @AppStorage("reminderOn") private var reminderOn = false
    @AppStorage("reminderMinutes") private var reminderMinutes = 20 * 60
    @State private var importing = false
    @State private var message: String?
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Оформление").textCase(nil)) {
                    Picker("Тема", selection: $theme) {
                        Text("Как в системе").tag(0)
                        Text("Светлая").tag(1)
                        Text("Тёмная").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Palette.surface)
                }

                Section(header: Text("Тренировка").textCase(nil)) {
                    Stepper("Цель дня: \(dailyGoal)", value: $dailyGoal, in: 10...200, step: 10)
                    Stepper("Новых в день: \(newPerDay)", value: $newPerDay, in: 0...60, step: 5)
                    Stepper("Карточек в сессии: \(sessionSize)", value: $sessionSize, in: 5...60, step: 5)
                }
                .listRowBackground(Palette.surface)

                Section {
                    Toggle("Напоминать каждый день", isOn: $reminderOn)
                    if reminderOn {
                        DatePicker("Время", selection: reminderTime, displayedComponents: .hourAndMinute)
                    }
                } header: { Text("Напоминание").textCase(nil) } footer: {
                    Text("Локальное уведомление, без интернета.")
                }
                .listRowBackground(Palette.surface)
                .onChange(of: reminderOn) { reschedule() }
                .onChange(of: reminderMinutes) { reschedule() }

                Section {
                    ForEach(store.packs) { pack in
                        Toggle(isOn: Binding(get: { store.isEnabled(pack) }, set: { store.setEnabled(pack, $0) })) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pack.title)
                                Text("\(pack.sourceName) · \(pack.cards.count) \(plural(pack.cards.count, "карточка", "карточки", "карточек"))")
                                    .font(.caption).foregroundStyle(Palette.ink2)
                            }
                        }
                    }
                    Button { importing = true } label: { Label("Импортировать пак (.json)", systemImage: "square.and.arrow.down") }
                } header: { Text("Паки в ежедневной тренировке").textCase(nil) } footer: {
                    Text("Пак — JSON-файл. Положи его в «Файлы» и импортируй. Пак с тем же id заменит старый, прогресс сохранится.")
                }
                .listRowBackground(Palette.surface)

                if !store.loadErrors.isEmpty {
                    Section(header: Text("Не удалось прочитать").textCase(nil)) {
                        ForEach(store.loadErrors, id: \.self) { Text($0).font(.caption) }
                    }
                    .listRowBackground(Palette.surface)
                }

                Section {
                    Button("Сбросить прогресс", role: .destructive) { confirmReset = true }
                } footer: {
                    Text("Recall · всё хранится только на телефоне.")
                }
                .listRowBackground(Palette.surface)
            }
            .scrollContentBackground(.hidden)
            .background(Palette.bg.ignoresSafeArea())
            .navigationTitle("Настройки")
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json], allowsMultipleSelection: true) { result in
                switch result {
                case .success(let urls):
                    var names: [String] = []
                    var errors: [String] = []
                    for url in urls {
                        do { names.append(try store.importPack(from: url)) }
                        catch { errors.append("\(url.lastPathComponent): \(error.localizedDescription)") }
                    }
                    message = (names.isEmpty ? "" : "Добавлено: " + names.joined(separator: ", "))
                        + (errors.isEmpty ? "" : "\nОшибки: " + errors.joined(separator: "; "))
                case .failure(let e):
                    message = e.localizedDescription
                }
            }
            .alert("Импорт", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK") { message = nil }
            } message: { Text(message ?? "") }
            .confirmationDialog("Сбросить весь прогресс?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Сбросить", role: .destructive) { store.resetProgress() }
            } message: { Text("Интервалы, стрик и рекорд блица обнулятся. Паки останутся.") }
        }
    }

    private var reminderTime: Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: reminderMinutes / 60, minute: reminderMinutes % 60, second: 0, of: .now) ?? .now
        } set: { d in
            let c = Calendar.current.dateComponents([.hour, .minute], from: d)
            reminderMinutes = (c.hour ?? 20) * 60 + (c.minute ?? 0)
        }
    }

    private func reschedule() {
        let on = reminderOn, m = reminderMinutes
        Task {
            let ok = await AppStore.scheduleReminder(enabled: on, hour: m / 60, minute: m % 60)
            if !ok { reminderOn = false; message = "Разреши уведомления в настройках iPhone." }
        }
    }
}
