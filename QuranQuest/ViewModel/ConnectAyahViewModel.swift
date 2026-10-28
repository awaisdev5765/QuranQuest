import Foundation

@MainActor
final class ConnectAyahViewModel: ObservableObject {
    @Published private(set) var viewState: ViewState = .empty
    @Published private(set) var gameState: GameState = .empty
    @Published private(set) var gameData: ConnectAyahQuestionModel?
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
        for surah in library.surahs.shuffled() {
            if let question = ConnectAyahQuestionModel(surah: surah) { gameData = question; viewState = .loaded; return }
        }
        errorMessage = library.error ?? "No Quran text is available for practice."; viewState = .failed
    }
}
