import Foundation

struct ConnectAyahQuestionModel {
    let question: String
    let questionAyahNumber: Int
    let options: [String]
    let correctOptionsIndex: Int
    let surahNumber: Int
    let reference: String

    init?(surah: SurahModel, promptIndex chosenIndex: Int? = nil) {
        guard let ayahs = surah.ayahs, ayahs.count >= 2 else { return nil }
        let promptIndex = chosenIndex ?? Int.random(in: 0..<(ayahs.count - 1))
        guard (0..<(ayahs.count - 1)).contains(promptIndex) else { return nil }
        let correct = ayahs[promptIndex + 1]
        // Equal displayed text must never be a wrong choice, even at another verse number.
        var seen: Set<String> = [correct.text]
        let alternatives = ayahs.shuffled().filter { seen.insert($0.text).inserted }.prefix(3).map(\.text)
        guard !alternatives.isEmpty else { return nil }
        question = ayahs[promptIndex].text
        questionAyahNumber = ayahs[promptIndex].globalNumber
        options = ([correct.text] + alternatives).shuffled()
        correctOptionsIndex = options.firstIndex(of: correct.text)!
        surahNumber = surah.number
        reference = "\(surah.englishName) · \(surah.number):\(ayahs[promptIndex].number) → \(correct.number)"
    }
}
