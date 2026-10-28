import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var progress: LearningProgress
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("arabicSize") private var arabicSize = 32.0
    @AppStorage("showTranslation") private var translation = false
    @ObservedObject private var player = RecitationPlayer.shared
    var body: some View {
        Form {
            Section("Reading") {
                Picker("Appearance", selection: $appearance) { Text("System").tag("system"); Text("Light").tag("light"); Text("Dark").tag("dark") }
                Toggle("English translation", isOn: $translation)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Arabic text size")
                    Slider(value: $arabicSize, in: 24...52, step: 2).accessibilityLabel("Arabic font size").accessibilityValue("\(Int(arabicSize)) points")
                    if let text = QuranLibrary.shared.surah(1)?.ayahs?.first?.text { ArabicText(text: text, size: arabicSize) }
                }
            }
            Section("Learning") {
                Stepper("Daily target: \(progress.dailyTarget) ayahs", value: $progress.dailyTarget, in: 1...100)
                NavigationLink("Practice history") { HistoryView() }
            }
            Section("Listening") {
                NavigationLink { ReciterPicker() } label: { LabeledContent("Reciter", value: player.selectedReciterName) }
                NavigationLink("Manage downloads") { DownloadsView() }
                Toggle("Play downloaded audio only", isOn: $player.offlineOnly)
            }
            Section("Sources") {
                Text("Arabic: Uthmani edition. English: Muhammad Marmaduke Pickthall. Quran text and verse audio are provided through Al Quran Cloud. Live radio directory: MP3Quran.").font(.footnote)
                Link("Quran text and audio source", destination: URL(string: "https://alquran.cloud")!)
                Link("Live radio source", destination: URL(string: "https://www.mp3quran.net")!)
                Text("Learning progress and bookmarks stay on this device. Audio downloads can be removed without deleting Quran text.").font(.footnote).foregroundStyle(.secondary)
            }
        }.navigationTitle("Settings")
    }
}

struct HistoryView: View {
    @EnvironmentObject private var progress: LearningProgress
    @State private var mistakesOnly = false
    var body: some View {
        List {
            Section {
                let correct = progress.history.filter(\.correct).count
                Text(progress.history.isEmpty ? "Your practice starts here" : "\(Int(Double(correct) / Double(progress.history.count) * 100))% recent accuracy").font(.title2.bold())
                Text("Based on your latest \(progress.history.count) answers. Up to 500 are saved.").font(.footnote).foregroundStyle(.secondary)
                Toggle("Show mistakes only", isOn: $mistakesOnly)
            }
            if progress.history.isEmpty { EmptyMessage(title: "A fresh start", detail: "Complete a quiz to track your accuracy and revisit answers.", icon: "chart.bar") }
            if mistakesOnly && !progress.history.isEmpty && progress.history.allSatisfy(\.correct) { Text("No mistakes in your saved history.") }
            Section("Recent answers") {
                ForEach(progress.history.filter { !mistakesOnly || !$0.correct }) { entry in
                    VStack(alignment: .leading, spacing: 12) {
                        Label(entry.correct ? "Correct" : "Revisit this verse", systemImage: entry.correct ? "checkmark.circle" : "arrow.counterclockwise").font(.headline)
                        Text(QuranLibrary.shared.reference(entry.ayah)).font(.subheadline).foregroundStyle(Color.appAccent)
                        ArabicText(text: entry.prompt, size: 26)
                        Text("Answer: \(entry.answer)").font(.body)
                        Text(entry.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                        if let location = QuranLibrary.shared.location(entry.ayah) { NavigationLink("Read in context") { SurahReaderView(surah: location.surah, initialAyah: entry.ayah) } }
                    }.padding(.vertical, 8)
                }
            }
            Section("Practice by surah") {
                ForEach(QuranLibrary.shared.surahs.filter { surah in progress.history.contains { $0.surah == surah.number } }, id: \.number) { surah in
                    let entries = progress.history.filter { $0.surah == surah.number }
                    LabeledContent(surah.englishName, value: "\(entries.filter(\.correct).count) / \(entries.count) correct")
                }
            }
        }.navigationTitle("Your practice")
    }
}
