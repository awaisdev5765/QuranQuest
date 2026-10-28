import SwiftUI

struct GuessSurahView: View {
    @StateObject private var vm = GuessSurahViewModel()
    @EnvironmentObject private var progress: LearningProgress
    var body: some View {
        QuizContainer(title: "Guess the Surah", prompt: "Which surah contains this ayah?", question: vm.gameData?.question, audioAyah: vm.gameData?.questionAyahNumber, options: vm.gameData?.options ?? [], correctAnswer: vm.gameData?.correctOptionsIndex, selected: vm.selectedAnswerIndex, state: vm.gameState, viewState: vm.viewState, error: vm.errorMessage, reference: vm.gameData?.reference, arabicAnswers: false, choose: vm.answer, next: vm.nextQuestion, retry: vm.loadGameResource)
            .onChange(of: vm.gameState) { state in
                guard state != .empty, let data = vm.gameData else { return }
                progress.record(PracticeEntry(surah: data.surahNumber, ayah: data.questionAyahNumber, prompt: data.question, answer: data.options[data.correctOptionsIndex], correct: state == .win))
            }
    }
}
