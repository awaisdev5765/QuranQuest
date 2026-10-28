import SwiftUI
import UIKit

struct ConnectAyahView: View {
    @StateObject private var vm = ConnectAyahViewModel()
    @EnvironmentObject private var progress: LearningProgress
    var body: some View {
        QuizContainer(title: "Continue the Ayah", prompt: "Which verse comes next?", question: vm.gameData?.question, audioAyah: vm.gameData?.questionAyahNumber, options: vm.gameData?.options ?? [], correctAnswer: vm.gameData?.correctOptionsIndex, selected: vm.selectedAnswerIndex, state: vm.gameState, viewState: vm.viewState, error: vm.errorMessage, reference: vm.gameData?.reference, arabicAnswers: true, choose: vm.answer, next: vm.nextQuestion, retry: vm.loadGameResource)
            .onChange(of: vm.gameState) { state in
                guard state != .empty, let data = vm.gameData else { return }
                progress.record(PracticeEntry(surah: data.surahNumber, ayah: data.questionAyahNumber, prompt: data.question, answer: data.options[data.correctOptionsIndex], correct: state == .win))
            }
    }
}

struct QuizContainer: View {
    let title: String
    let prompt: String
    let question: String?
    let audioAyah: Int?
    let options: [String]
    let correctAnswer: Int?
    let selected: Int?
    let state: GameState
    let viewState: ViewState
    let error: String?
    let reference: String?
    let arabicAnswers: Bool
    let choose: (Int) -> Void
    let next: () -> Void
    let retry: () -> Void
    @ObservedObject private var player = RecitationPlayer.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var resultFocused: Bool

    var body: some View {
        Group {
            switch viewState {
            case .loading, .empty:
                ProgressView("Preparing your practice…").frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed:
                VStack(spacing: 16) {
                    EmptyMessage(title: "Practice unavailable", detail: error ?? "Please try again.", icon: "exclamationmark.circle")
                    Button("Try again", action: retry).buttonStyle(.borderedProminent)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded:
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            Text(prompt).font(.headline).foregroundStyle(.secondary)
                            questionCard
                            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                                answer(option, index: index)
                            }
                            if state != .empty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Label(state == .win ? "Correct — well done." : "Keep going. Review the answer below.", systemImage: state == .win ? "checkmark.circle.fill" : "arrow.counterclockwise")
                                        .font(.headline).accessibilityFocused($resultFocused)
                                    if let correctAnswer, options.indices.contains(correctAnswer) {
                                        if arabicAnswers { ArabicText(text: options[correctAnswer], size: 28) }
                                        else { Text(options[correctAnswer]).font(.title3.bold()) }
                                    }
                                    if let reference { Text(reference).font(.subheadline).foregroundStyle(.secondary) }
                                    Button { player.stop(); next(); proxy.scrollTo("top", anchor: .top) } label: { Text("Next question").frame(maxWidth: .infinity, minHeight: 44) }.buttonStyle(.borderedProminent)
                                }.padding(20).background(Color.appCard, in: RoundedRectangle(cornerRadius: 20)).id("result").transition(.opacity)
                            }
                        }.padding(20).frame(maxWidth: 720).id("top")
                    }.frame(maxWidth: .infinity)
                        .onChange(of: state) { value in
                            guard value != .empty else { return }
                            UINotificationFeedbackGenerator().notificationOccurred(value == .win ? .success : .warning)
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) { proxy.scrollTo("result", anchor: .bottom) }
                            resultFocused = true
                        }
                }
            }
        }.background(Color.appBackground).navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: state)
            .onDisappear { player.stop() }
    }
    private var questionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            ArabicText(text: question ?? "")
            if let audioAyah {
                Button {
                    if player.playingAyah == audioAyah { player.canPause ? player.pause() : player.resume() }
                    else { player.play(ayahs: [audioAyah], titleOverride: "Practice recitation") }
                } label: {
                    Label(player.playingAyah == audioAyah && player.canPause ? "Pause recitation" : "Listen to verse", systemImage: player.playingAyah == audioAyah && player.canPause ? "pause.fill" : "play.fill")
                }.buttonStyle(.bordered).controlSize(.large)
                if player.playingAyah == audioAyah && player.state == .loading { ProgressView("Loading recitation…") }
                if player.playingAyah == audioAyah, let error = player.errorMessage { Text(error).font(.footnote); Button("Retry audio") { player.retry() } }
            }
        }.padding(20).background(Color.appCard, in: RoundedRectangle(cornerRadius: 24))
    }
    private func answer(_ text: String, index: Int) -> some View {
        let correct = state != .empty && index == correctAnswer
        let wrong = state == .lose && index == selected
        let symbol = correct ? "checkmark.circle.fill" : wrong ? "xmark.circle.fill" : "circle"
        return Button { choose(index) } label: {
            HStack(spacing: 16) {
                Image(systemName: symbol).foregroundStyle(correct ? Color.appAccent : wrong ? Color.red : Color.secondary).accessibilityHidden(true)
                if arabicAnswers { ArabicText(text: text, size: 28) }
                else { Text(text).font(.body.weight(.medium)).frame(maxWidth: .infinity, alignment: .leading) }
            }.padding(16).frame(minHeight: 56).foregroundStyle(.primary)
                .background(Color.appCard, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(correct ? Color.appAccent : wrong ? Color.red : Color.secondary.opacity(0.4), lineWidth: correct || wrong ? 2 : 1))
        }.buttonStyle(.plain).disabled(state != .empty)
            .accessibilityLabel(text).accessibilityValue(correct ? "Correct answer" : wrong ? "Your answer, incorrect" : "")
            .accessibilityHint(state == .empty ? "Select this answer" : "Answer submitted")
    }
}
