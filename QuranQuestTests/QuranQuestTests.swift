import XCTest
@testable import QuranQuest

final class QuranQuestTests: XCTestCase {
    func testOfflineLibraryHasEveryVerseAndTranslation() throws {
        let library = QuranLibrary.shared
        XCTAssertNil(library.error)
        try QuranLibrary.validate(library.surahs)
        XCTAssertEqual(library.surahs.count, 114)
        XCTAssertEqual(library.surah(114)?.ayahs?.last?.globalNumber, 6236)
        for number in 1...6236 { XCTAssertFalse(library.translation(number)?.isEmpty ?? true) }
        XCTAssertEqual(Set(library.surahs.flatMap { $0.ayahs ?? [] }.map(\.juz)), Set(1...30))
    }
    func testEveryEligibleContinuePromptIncludesCorrectSuccessor() throws {
        for surah in QuranLibrary.shared.surahs {
            let ayahs = try XCTUnwrap(surah.ayahs)
            for index in 0..<(ayahs.count - 1) {
                let question = try XCTUnwrap(ConnectAyahQuestionModel(surah: surah, promptIndex: index))
                XCTAssertEqual(question.options[question.correctOptionsIndex], ayahs[index + 1].text)
                XCTAssertEqual(question.questionAyahNumber, ayahs[index].globalNumber)
                XCTAssertEqual(Set(question.options).count, question.options.count)
            }
        }
    }
    func testShortSurahAndRepeatedTextChoices() throws {
        let surah = SurahModel(number: 1, name: "Test", englishName: "Test", englishNameTranslation: "Test", numberOfAyahs: 3, revelationType: "Test", ayahs: [
            AyahModel(number: 1, globalNumber: 1, text: "First"),
            AyahModel(number: 2, globalNumber: 2, text: "Repeated"),
            AyahModel(number: 3, globalNumber: 3, text: "Repeated")
        ])
        let question = try XCTUnwrap(ConnectAyahQuestionModel(surah: surah, promptIndex: 1))
        XCTAssertEqual(question.options.count, 2)
        XCTAssertEqual(question.options[question.correctOptionsIndex], "Repeated")
        XCTAssertNil(ConnectAyahQuestionModel(surah: surah, promptIndex: 2))
    }
    func testRepeatSequenceHasExactVerseAndRangeCounts() {
        XCTAssertEqual(PlaybackPlan(ayahs: [5, 6], repetitions: 2, rounds: 2).ayahs, [5, 5, 6, 6, 5, 5, 6, 6])
        XCTAssertEqual(PlaybackPlan(ayahs: [], repetitions: 3).ayahs, [])
        XCTAssertEqual(PlaybackPlan(ayahs: [1], repetitions: 0).ayahs, [1])
    }
    @MainActor func testStreakSameDayConsecutiveGapAndRelaunch() throws {
        let suite = "QuranTests.\(UUID())"; let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let first = calendar.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 12))!
        let next = calendar.date(byAdding: .day, value: 1, to: first)!
        let afterGap = calendar.date(byAdding: .day, value: 4, to: first)!
        let progress = LearningProgress(defaults: defaults, calendar: calendar, now: first)
        progress.recordPractice(ayahs: [1], now: first); progress.recordPractice(ayahs: [1, 2], now: first)
        XCTAssertEqual(progress.dailyStreak, 1); XCTAssertEqual(progress.practicedToday.count, 2)
        progress.recordPractice(ayahs: [3], now: next)
        XCTAssertEqual(progress.dailyStreak, 2); XCTAssertEqual(progress.practicedToday, [3])
        let restored = LearningProgress(defaults: defaults, calendar: calendar, now: next)
        XCTAssertEqual(restored.dailyStreak, 2)
        restored.refresh(now: afterGap); XCTAssertEqual(restored.dailyStreak, 0); XCTAssertTrue(restored.practicedToday.isEmpty)
        restored.recordPractice(ayahs: [4], now: afterGap); XCTAssertEqual(restored.dailyStreak, 1)
    }
    @MainActor func testBookmarksAndHifzRevisionPersist() throws {
        let suite = "QuranTests.\(UUID())"; let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let now = Date(); let progress = LearningProgress(defaults: defaults, now: now)
        progress.toggleBookmark(3); progress.lastRead = 3
        let plan = HifzPlan(surah: 1, start: 1, end: 3)
        progress.savePlan(plan); progress.assess(plan.id, confident: true, now: now)
        let restored = LearningProgress(defaults: defaults, now: now)
        XCTAssertEqual(restored.bookmarks, [3]); XCTAssertEqual(restored.lastRead, 3)
        XCTAssertEqual(restored.plans.first?.sessions, 1)
        XCTAssertEqual(restored.plans.first?.interval, 1)
        XCTAssertGreaterThan(try XCTUnwrap(restored.plans.first?.due), now)
        XCTAssertEqual(restored.practicedToday, [1, 2, 3])
        restored.assess(plan.id, confident: true, now: now)
        XCTAssertEqual(restored.plans.first?.interval, 2)
        restored.assess(plan.id, confident: false, now: now)
        XCTAssertEqual(restored.plans.first?.interval, 1)
    }
    @MainActor func testOfflineAudioIsScopedByReciterAndRemovalPreservesText() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let downloads = AudioDownloads(root: root)
        let folder = root.appendingPathComponent("ar.alafasy")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data([1, 2, 3]).write(to: folder.appendingPathComponent("1.mp3"))
        XCTAssertNotNil(downloads.localURL(reciter: "ar.alafasy", ayah: 1))
        XCTAssertNil(downloads.localURL(reciter: "ar.husary", ayah: 1))
        XCTAssertNil(AudioDownloads.remoteURL(reciter: "../escape", ayah: 1))
        let surah = try XCTUnwrap(QuranLibrary.shared.surah(1))
        XCTAssertEqual(downloads.count(surah, reciter: "ar.alafasy"), 1)
        downloads.remove(surah, reciter: "ar.alafasy")
        XCTAssertNil(downloads.localURL(reciter: "ar.alafasy", ayah: 1))
        XCTAssertEqual(surah.ayahs?.count, 7)
    }
    @MainActor func testQuizRejectsInvalidAndRepeatedAnswers() throws {
        let vm = GuessSurahViewModel()
        let question = try XCTUnwrap(vm.gameData)
        vm.answer(-1); XCTAssertEqual(vm.gameState, .empty)
        vm.answer(question.correctOptionsIndex); XCTAssertEqual(vm.gameState, .win)
        vm.answer((question.correctOptionsIndex + 1) % question.options.count); XCTAssertEqual(vm.gameState, .win)
        vm.nextQuestion(); XCTAssertEqual(vm.gameState, .empty); XCTAssertNil(vm.selectedAnswerIndex)
    }
    @MainActor func testMissingOfflineAudioReportsFailureAndStopClearsQueue() {
        let player = RecitationPlayer.shared
        let original = player.offlineOnly
        defer { player.stop(); player.offlineOnly = original }
        player.offlineOnly = true
        player.play(ayahs: [6236])
        XCTAssertEqual(player.state, .failed)
        XCTAssertNotNil(player.errorMessage)
        player.stop()
        XCTAssertEqual(player.state, .idle); XCTAssertTrue(player.queue.isEmpty); XCTAssertNil(player.playingAyah)
    }
}
