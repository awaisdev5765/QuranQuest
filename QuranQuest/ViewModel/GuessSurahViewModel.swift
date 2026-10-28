import Foundation

enum ViewState { case empty, loading, loaded, failed }
enum GameState: Equatable { case empty, win, lose }

@MainActor
final class GuessSurahViewModel: ObservableObject {
    @Published private(set) var viewState: ViewState = .empty
    @Published private(set) var gameState: GameState = .empty
    @Published private(set) var gameData: GuessSurahQuestionModel?
    @Published private(set) var selectedAnswerIndex: Int?
    @Published private(set) var errorMessage: String?
    private let library: QuranLibrary
    init(library: QuranLibrary = .shared) { self.library = library; loadGameResource() }
    func answer(_ index: Int) {
        guard gameState == .empty, let gameData, gameData.options.indices.contains(index) else { return }
        selectedAnswerIndex = index
        gameState = index == gameData.correctOptionsIndex ? .win : .lose
    }
    func nextQuestion() { loadGameResource() }
    func loadGameResource() {
        gameState = .empty; selectedAnswerIndex = nil; gameData = nil; errorMessage = nil
        let choices = Array(library.surahs.shuffled().prefix(4))
        if let correct = choices.randomElement(), let question = GuessSurahQuestionModel(correctSurah: correct, choices: choices) {
            gameData = question; viewState = .loaded
        } else { errorMessage = library.error ?? "No Quran text is available for practice."; viewState = .failed }
    }
}
