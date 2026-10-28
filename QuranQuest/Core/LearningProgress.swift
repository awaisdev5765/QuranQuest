import Foundation

struct PracticeEntry: Codable, Identifiable {
    var id = UUID()
    var date = Date()
    let surah: Int
    let ayah: Int
    let prompt: String
    let answer: String
    let correct: Bool
}

struct HifzPlan: Codable, Identifiable {
    var id = UUID()
    var surah: Int
    var start: Int
    var end: Int
    var repetitions = 3
    var pauseSeconds = 2
    var rounds = 1
    var due = Date()
    var interval = 0
    var sessions = 0
}

@MainActor
final class LearningProgress: ObservableObject {
    @Published private(set) var correctAnswers: Int
    @Published private(set) var dailyStreak: Int
    @Published private(set) var history: [PracticeEntry]
    @Published private(set) var bookmarks: Set<Int>
    @Published private(set) var plans: [HifzPlan]
    @Published var lastRead: Int { didSet { defaults.set(lastRead, forKey: "lastRead") } }
    @Published var dailyTarget: Int { didSet { defaults.set(dailyTarget, forKey: "dailyTarget") } }
    @Published private(set) var practicedToday: Set<Int> = []
    private let defaults: UserDefaults
    private let calendar: Calendar
    private var practiceDay: Date

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current, now: Date = Date()) {
        self.defaults = defaults
        self.calendar = calendar
        correctAnswers = defaults.integer(forKey: "correctAnswers")
        dailyStreak = defaults.integer(forKey: "dailyStreak")
        history = Self.read([PracticeEntry].self, "practiceHistory", defaults) ?? []
        bookmarks = Set(defaults.array(forKey: "bookmarks") as? [Int] ?? [])
        plans = Self.read([HifzPlan].self, "hifzPlans", defaults) ?? []
        lastRead = max(1, defaults.integer(forKey: "lastRead"))
        dailyTarget = max(1, defaults.integer(forKey: "dailyTarget"))
        practiceDay = defaults.object(forKey: "practiceDay") as? Date ?? now
        if calendar.isDate(practiceDay, inSameDayAs: now) {
            practicedToday = Set(defaults.array(forKey: "practicedToday") as? [Int] ?? [])
        }
        // Old versions counted active days rather than consecutive days.
        if !defaults.bool(forKey: "streakV2") {
            dailyStreak = 0
            defaults.removeObject(forKey: "lastPracticeDate")
            defaults.set(true, forKey: "streakV2")
        }
        refresh(now: now)
    }
    private static func read<T: Decodable>(_ type: T.Type, _ key: String, _ defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
    private func save<T: Encodable>(_ value: T, _ key: String) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }
    func refresh(now: Date = Date()) {
        if let last = defaults.object(forKey: "lastPracticeDate") as? Date {
            let gap = calendar.dateComponents([.day], from: calendar.startOfDay(for: last), to: calendar.startOfDay(for: now)).day ?? 0
            if gap > 1 || gap < 0 { dailyStreak = 0 }
        } else { dailyStreak = 0 }
        defaults.set(dailyStreak, forKey: "dailyStreak")
        if !calendar.isDate(practiceDay, inSameDayAs: now) {
            practicedToday = []; practiceDay = now
            defaults.set([], forKey: "practicedToday")
            defaults.set(now, forKey: "practiceDay")
        }
    }
    func recordPractice(ayahs: [Int], now: Date = Date()) {
        refresh(now: now)
        let last = defaults.object(forKey: "lastPracticeDate") as? Date
        if last == nil || !calendar.isDate(last!, inSameDayAs: now) { dailyStreak += 1 }
        defaults.set(now, forKey: "lastPracticeDate")
        defaults.set(dailyStreak, forKey: "dailyStreak")
        practicedToday.formUnion(ayahs)
        practiceDay = now
        defaults.set(now, forKey: "practiceDay")
        defaults.set(Array(practicedToday), forKey: "practicedToday")
    }
    func record(_ entry: PracticeEntry) {
        history.insert(entry, at: 0)
        history = Array(history.prefix(500))
        if entry.correct { correctAnswers += 1; defaults.set(correctAnswers, forKey: "correctAnswers") }
        recordPractice(ayahs: [entry.ayah])
        save(history, "practiceHistory")
    }
    func toggleBookmark(_ ayah: Int) {
        if bookmarks.contains(ayah) { bookmarks.remove(ayah) } else { bookmarks.insert(ayah) }
        defaults.set(Array(bookmarks), forKey: "bookmarks")
    }
    func savePlan(_ plan: HifzPlan) {
        if let index = plans.firstIndex(where: { $0.id == plan.id }) { plans[index] = plan }
        else { plans.append(plan) }
        save(plans, "hifzPlans")
    }
    func deletePlan(_ id: UUID) { plans.removeAll { $0.id == id }; save(plans, "hifzPlans") }
    func assess(_ id: UUID, confident: Bool, now: Date = Date()) {
        guard let index = plans.firstIndex(where: { $0.id == id }) else { return }
        plans[index].sessions += 1
        plans[index].interval = confident ? min(30, max(1, plans[index].interval * 2)) : 1
        plans[index].due = calendar.date(byAdding: .day, value: plans[index].interval, to: now) ?? now
        let plan = plans[index]
        let ayahs = QuranLibrary.shared.surah(plan.surah)?.ayahs?.filter { (plan.start...plan.end).contains($0.number) }.map(\.globalNumber) ?? []
        recordPractice(ayahs: ayahs, now: now)
        save(plans, "hifzPlans")
    }
}
