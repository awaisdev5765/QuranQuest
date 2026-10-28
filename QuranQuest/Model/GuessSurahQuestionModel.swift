import Foundation

struct GuessSurahQuestionModel {
    let question: String
    let questionAyahNumber: Int
    let options: [String]
    let correctOptionsIndex: Int
    let surahNumber: Int
    let reference: String

    init?(correctSurah: SurahModel, choices: [SurahModel]) {
        guard let prompt = correctSurah.ayahs?.randomElement(), !prompt.text.isEmpty else { return nil }
        var seen: Set<Int> = []
        let choices = ([correctSurah] + choices).filter { seen.insert($0.number).inserted }.shuffled()
        guard choices.count >= 2 else { return nil }
        question = prompt.text; questionAyahNumber = prompt.globalNumber
        options = choices.map(\.englishName)
        correctOptionsIndex = choices.firstIndex { $0.number == correctSurah.number }!
        surahNumber = correctSurah.number
        reference = "\(correctSurah.englishName) · \(correctSurah.number):\(prompt.number)"
    }
}
