import SwiftUI

struct HifzView: View {
    @EnvironmentObject private var progress: LearningProgress
    @State private var create = false
    var body: some View {
        List {
            Section {
                Text("Listen. Recall. Revisit.").font(.title2.bold())
                Text("Choose a small range, repeat at your pace, then return for revision. Progress is based on your own recall check.").foregroundStyle(.secondary)
                Button { create = true } label: { Label("New memorization plan", systemImage: "plus.circle.fill") }.frame(minHeight: 44)
            }
            Section("Ready for revision") {
                let due = progress.plans.filter { $0.due <= Date() }
                if due.isEmpty { Text("No revisions due. Create a plan or continue one below.").foregroundStyle(.secondary) }
                ForEach(due) { plan in planLink(plan) }
            }
            Section("Your plans") {
                if progress.plans.isEmpty { Text("Start with a few ayahs. Your range, repeat settings and revision dates will be saved here.").foregroundStyle(.secondary) }
                ForEach(progress.plans) { plan in planLink(plan) }
                    .onDelete { indices in let ids = indices.map { progress.plans[$0].id }; ids.forEach(progress.deletePlan) }
            }
        }.navigationTitle("Hifz")
            .sheet(isPresented: $create) { NavigationStack { HifzPlanEditor() }.environmentObject(progress) }
    }
    private func planLink(_ plan: HifzPlan) -> some View {
        NavigationLink { HifzSessionView(planID: plan.id) } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(QuranLibrary.shared.surah(plan.surah)?.englishName ?? "Surah") · \(plan.start)–\(plan.end)").font(.headline)
                Text("\(plan.sessions) self-checks · Review \(plan.due.formatted(date: .abbreviated, time: .omitted))").font(.caption).foregroundStyle(.secondary)
            }.padding(.vertical, 8)
        }
    }
}

struct HifzPlanEditor: View {
    @EnvironmentObject private var progress: LearningProgress
    @Environment(\.dismiss) private var dismiss
    @State private var surah = 1
    @State private var start = 1
    @State private var end = 3
    @State private var repetitions = 3
    @State private var pause = 2
    @State private var rounds = 1
    private var maxAyahs: Int { QuranLibrary.shared.surah(surah)?.numberOfAyahs ?? 1 }
    var body: some View {
        Form {
            Picker("Surah", selection: $surah) { ForEach(QuranLibrary.shared.surahs, id: \.number) { Text("\($0.number). \($0.englishName)").tag($0.number) } }
            Stepper("First ayah: \(start)", value: $start, in: 1...maxAyahs)
            Stepper("Last ayah: \(end)", value: $end, in: start...maxAyahs)
            Stepper("Repeat each verse: \(repetitions)×", value: $repetitions, in: 1...10)
            Stepper("Repeat whole range: \(rounds)×", value: $rounds, in: 1...5)
            Stepper("Recall pause: \(pause) seconds", value: $pause, in: 0...15)
            Section { Button("Save plan") {
                progress.savePlan(HifzPlan(surah: surah, start: start, end: end, repetitions: repetitions, pauseSeconds: pause, rounds: rounds)); dismiss()
            }.disabled(QuranLibrary.shared.surahs.isEmpty) } footer: { Text("Repetitions play each ayah before moving on. The recall pause gives you time to recite aloud.") }
        }.navigationTitle("New Hifz plan").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .onChange(of: surah) { _ in start = 1; end = min(3, maxAyahs) }
            .onChange(of: start) { value in end = max(end, value) }
    }
}

struct HifzSessionView: View {
    let planID: UUID
    @EnvironmentObject private var progress: LearningProgress
    @ObservedObject private var player = RecitationPlayer.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hidden = false
    @State private var revealed: Set<Int> = []
    @State private var assessed = false
    @State private var showAssessment = false
    private var plan: HifzPlan? { progress.plans.first { $0.id == planID } }
    var body: some View {
        ScrollView {
            if let plan, let surah = QuranLibrary.shared.surah(plan.surah) {
                let ayahs = (surah.ayahs ?? []).filter { (plan.start...plan.end).contains($0.number) }
                VStack(alignment: .leading, spacing: 20) {
                    Text("\(surah.englishName) · Ayahs \(plan.start)–\(plan.end)").font(.title2.bold())
                    Text("Listen, recite with the text, then hide it and recall. Use the player below to pause or change speed.").foregroundStyle(.secondary)
                    Stepper("Each verse: \(plan.repetitions)×", value: Binding(get: { self.plan?.repetitions ?? 3 }, set: { var updated = plan; updated.repetitions = $0; progress.savePlan(updated) }), in: 1...10)
                    Stepper("Whole range: \(plan.rounds)×", value: Binding(get: { self.plan?.rounds ?? 1 }, set: { var updated = plan; updated.rounds = $0; progress.savePlan(updated) }), in: 1...5)
                    Stepper("Recall pause: \(plan.pauseSeconds)s", value: Binding(get: { self.plan?.pauseSeconds ?? 2 }, set: { var updated = plan; updated.pauseSeconds = $0; progress.savePlan(updated) }), in: 0...15)
                    Button {
                        assessed = false
                        player.play(ayahs: ayahs.map(\.id), repetitions: plan.repetitions, rounds: plan.rounds, pause: Double(plan.pauseSeconds))
                    } label: { Label("Start listening practice", systemImage: "play.circle.fill") }.buttonStyle(.borderedProminent).controlSize(.large)
                    DownloadControl(surah: surah)
                    Toggle("Hide verses for recall", isOn: $hidden).onChange(of: hidden) { _ in revealed = [] }
                    ForEach(ayahs) { ayah in
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Ayah \(ayah.number)").font(.headline).foregroundStyle(Color.appAccent)
                            if !hidden || revealed.contains(ayah.id) { ArabicText(text: ayah.text) }
                            else { Text("Recite from memory, then reveal to check.").foregroundStyle(.secondary) }
                            if hidden {
                                Button(revealed.contains(ayah.id) ? "Hide ayah" : "Reveal ayah") {
                                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                                        if revealed.contains(ayah.id) { revealed.remove(ayah.id) } else { revealed.insert(ayah.id) }
                                    }
                                }.frame(minHeight: 44)
                            }
                        }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(Color.appCard, in: RoundedRectangle(cornerRadius: 20))
                    }
                    if assessed {
                        Label("Practice saved. Your next revision is scheduled.", systemImage: "checkmark.circle").foregroundStyle(Color.appAccent)
                        Button("Start another recall check") { assessed = false }
                    } else {
                        Button("Finish with a self-check") { showAssessment = true }.buttonStyle(.borderedProminent).controlSize(.large)
                    }
                    Text("Self-assessment records your confidence. This app does not grade pronunciation or tajweed.").font(.footnote).foregroundStyle(.secondary)
                }.padding(20).frame(maxWidth: 720)
            }
        }.frame(maxWidth: .infinity).background(Color.appBackground).navigationTitle("Memorize").navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("How did your recall go?", isPresented: $showAssessment, titleVisibility: .visible) {
                Button("Confident — schedule revision") { finish(confident: true) }
                Button("Needs practice — revisit tomorrow") { finish(confident: false) }
                Button("Keep practicing", role: .cancel) { }
            }
    }
    private func finish(confident: Bool) { progress.assess(planID, confident: confident); assessed = true; player.stop() }
}
